#!/usr/bin/env python3
"""
Generate a richer Outlook .msg (Compound File Binary v3) fixture containing:

  - Subject / SenderName / SenderEmailAddress / DisplayTo / DisplayCc
  - ClientSubmitTime (FILETIME, PT_SYSTIME)
  - Body (plain, UTF-16LE) and Html (binary UTF-8)
  - Attachment sub-storage with a small PDF
  - Inline image sub-storage with a 1x1 PNG referenced by cid:logo@example

Directory layout uses nested storages via child/left/right rb-tree links.
All streams go into the Mini Stream (each < 4096 bytes).
"""

from __future__ import annotations

import base64
import struct
import sys
from io import BytesIO
from pathlib import Path

SECTOR_SIZE        = 512
MINI_SECTOR_SIZE   = 64
MINI_STREAM_CUTOFF = 4096

FREESECT   = 0xFFFFFFFF
ENDOFCHAIN = 0xFFFFFFFE
FATSECT    = 0xFFFFFFFD
DIR_ENTRY_SIZE = 128
NOSTREAM = 0xFFFFFFFF

OBJ_STORAGE = 1
OBJ_STREAM  = 2
OBJ_ROOT    = 5


def u16le(s: str) -> bytes:
    return s.encode("utf-16-le")


def pad_to(data: bytes, size: int, fill: bytes = b"\x00") -> bytes:
    rem = len(data) % size
    return data if rem == 0 else data + fill * (size - rem)


def filetime_now() -> bytes:
    """2026-04-16 14:30:00 UTC → FILETIME (LE 8 bytes)."""
    import datetime as _dt
    epoch = _dt.datetime(1601, 1, 1, tzinfo=_dt.timezone.utc)
    when  = _dt.datetime(2026, 4, 16, 14, 30, 0, tzinfo=_dt.timezone.utc)
    delta = when - epoch
    ticks = int(delta.total_seconds() * 10_000_000)
    return struct.pack("<Q", ticks)


def minimal_pdf() -> bytes:
    out = BytesIO()
    offsets = [0]
    parts = [
        b"%PDF-1.4\n",
        b"1 0 obj\n<</Type /Catalog /Pages 2 0 R>>\nendobj\n",
        b"2 0 obj\n<</Type /Pages /Kids [3 0 R] /Count 1>>\nendobj\n",
        b"3 0 obj\n<</Type /Page /Parent 2 0 R /MediaBox [0 0 200 200] /Resources <<>>>>\nendobj\n",
    ]
    for p in parts:
        offsets.append(out.tell())
        out.write(p)
    xref_pos = out.tell()
    out.write(b"xref\n0 4\n")
    out.write(b"0000000000 65535 f \n")
    for off in offsets[1:4]:
        out.write(f"{off:010d} 00000 n \n".encode())
    out.write(b"trailer\n<</Size 4 /Root 1 0 R>>\n")
    out.write(f"startxref\n{xref_pos}\n".encode())
    out.write(b"%%EOF\n")
    return out.getvalue()


ONE_PX_PNG = base64.b64decode(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+P+/HgAFhAJ/wlseKgAAAABJRU5ErkJggg=="
)


def build_dir_entry(
    name: str,
    obj_type: int,
    *,
    left: int = NOSTREAM,
    right: int = NOSTREAM,
    child: int = NOSTREAM,
    start_sector: int = 0,
    size: int = 0,
) -> bytes:
    name_utf16 = name.encode("utf-16-le")
    assert len(name_utf16) <= 62, f"name too long: {name!r}"
    entry = bytearray(DIR_ENTRY_SIZE)
    entry[0:len(name_utf16)] = name_utf16
    struct.pack_into("<H", entry, 64, len(name_utf16) + 2)
    entry[66] = obj_type
    entry[67] = 0x01
    struct.pack_into("<I", entry, 68, left)
    struct.pack_into("<I", entry, 72, right)
    struct.pack_into("<I", entry, 76, child)
    struct.pack_into("<I", entry, 116, start_sector)
    struct.pack_into("<Q", entry, 120, size)
    return bytes(entry)


def build_header(
    *,
    dir_start: int,
    fat_sectors: list[int],
    mini_fat_start: int,
    mini_fat_count: int,
) -> bytes:
    h = bytearray(SECTOR_SIZE)
    h[0:8] = b"\xD0\xCF\x11\xE0\xA1\xB1\x1A\xE1"
    struct.pack_into("<H", h, 24, 0x003E)
    struct.pack_into("<H", h, 26, 0x0003)
    struct.pack_into("<H", h, 28, 0xFFFE)
    struct.pack_into("<H", h, 30, 9)
    struct.pack_into("<H", h, 32, 6)
    struct.pack_into("<I", h, 40, 0)
    struct.pack_into("<I", h, 44, len(fat_sectors))
    struct.pack_into("<I", h, 48, dir_start)
    struct.pack_into("<I", h, 52, 0)
    struct.pack_into("<I", h, 56, MINI_STREAM_CUTOFF)
    struct.pack_into("<I", h, 60, mini_fat_start)
    struct.pack_into("<I", h, 64, mini_fat_count)
    struct.pack_into("<I", h, 68, ENDOFCHAIN)
    struct.pack_into("<I", h, 72, 0)
    for i in range(109):
        v = fat_sectors[i] if i < len(fat_sectors) else FREESECT
        struct.pack_into("<I", h, 76 + i * 4, v)
    return bytes(h)


def rb_links(n: int) -> tuple[list[tuple[int, int]], int]:
    pairs = [(NOSTREAM, NOSTREAM)] * n
    if n == 0:
        return pairs, NOSTREAM

    def build(lo: int, hi: int) -> int:
        if lo >= hi:
            return NOSTREAM
        m = (lo + hi) // 2
        left  = build(lo, m)
        right = build(m + 1, hi)
        pairs[m] = (left, right)
        return m

    root = build(0, n)
    return pairs, root


class StorageNode:
    def __init__(self, name: str, obj_type: int):
        self.name = name
        self.obj_type = obj_type
        self.children: list["StorageNode"] = []
        self.payload: bytes = b""
        self.dir_index: int = -1
        self.mini_start: int = 0

    def add(self, child: "StorageNode") -> "StorageNode":
        self.children.append(child)
        return child


def assign_dir_indices(root: StorageNode) -> list[StorageNode]:
    ordered: list[StorageNode] = []

    def visit(node: StorageNode) -> None:
        ordered.append(node)
        node.dir_index = len(ordered) - 1
        for c in node.children:
            visit(c)

    visit(root)
    return ordered


def main(out_path: str) -> None:
    root = StorageNode("Root Entry", OBJ_ROOT)

    def add_unicode(parent: StorageNode, tag4: str, text: str) -> None:
        parent.add(StorageNode(f"__substg1.0_{tag4}001F", OBJ_STREAM)).payload = u16le(text)

    def add_binary(parent: StorageNode, tag4: str, payload: bytes) -> None:
        parent.add(StorageNode(f"__substg1.0_{tag4}0102", OBJ_STREAM)).payload = payload

    def add_filetime(parent: StorageNode, tag4: str, value: bytes) -> None:
        assert len(value) == 8
        parent.add(StorageNode(f"__substg1.0_{tag4}0040", OBJ_STREAM)).payload = value

    add_unicode(root, "0037", "Test Outlook message with attachments")
    add_unicode(root, "0C1A", "Alice Example")
    add_unicode(root, "0C1F", "alice@example.com")
    add_unicode(root, "0E04", "Bob Example <bob@example.com>")
    add_unicode(root, "0E03", "Carol Example <carol@example.com>")
    add_filetime(root, "0039", filetime_now())
    add_unicode(root, "1000",
        "Hi Bob,\r\n\r\n"
        "This is a synthetic Outlook .msg test fixture.\r\n"
        "It ships with a PDF attachment and an inline 1x1 PNG.\r\n\r\n"
        "Best,\r\nAlice")
    add_binary(root, "1013",
        b"<!doctype html><html><body style=\"font-family:-apple-system\">"
        b"<p>Hi Bob,</p>"
        b"<p>This is a <strong>synthetic</strong> Outlook <code>.msg</code> test fixture.</p>"
        b"<p>It ships with a PDF attachment and an inline 1x1 PNG:</p>"
        b"<p><img src=\"cid:logo@example\"></p>"
        b"<p>Best,<br>Alice</p>"
        b"</body></html>")

    att0 = root.add(StorageNode("__attach_version1.0_#00000000", OBJ_STORAGE))
    add_unicode(att0, "3704", "agenda.pdf")
    add_unicode(att0, "3707", "agenda.pdf")
    add_unicode(att0, "370E", "application/pdf")
    add_binary(att0, "3701", minimal_pdf())

    att1 = root.add(StorageNode("__attach_version1.0_#00000001", OBJ_STORAGE))
    add_unicode(att1, "3704", "logo.png")
    add_unicode(att1, "3707", "logo.png")
    add_unicode(att1, "370E", "image/png")
    add_unicode(att1, "3712", "<logo@example>")
    add_binary(att1, "3701", ONE_PX_PNG)

    ordered = assign_dir_indices(root)
    for node in ordered:
        if node.obj_type in (OBJ_STORAGE, OBJ_ROOT) and node.children:
            _, child_root = rb_links(len(node.children))

    mini_stream = bytearray()
    mini_fat: list[int] = []
    for node in ordered:
        if node.obj_type != OBJ_STREAM:
            continue
        first_mini = len(mini_stream) // MINI_SECTOR_SIZE
        node.mini_start = first_mini
        payload = node.payload
        n_mini = max(1, (len(payload) + MINI_SECTOR_SIZE - 1) // MINI_SECTOR_SIZE)
        for i in range(n_mini - 1):
            mini_fat.append(first_mini + i + 1)
        mini_fat.append(ENDOFCHAIN)
        mini_stream += payload
        mini_stream += b"\x00" * (n_mini * MINI_SECTOR_SIZE - len(payload))

    while (len(mini_fat) * 4) % SECTOR_SIZE != 0:
        mini_fat.append(FREESECT)
    mini_fat_bytes = b"".join(struct.pack("<I", v) for v in mini_fat)
    mini_fat_sector_count = len(mini_fat_bytes) // SECTOR_SIZE

    mini_stream_size = len(mini_stream)
    mini_stream = pad_to(bytes(mini_stream), SECTOR_SIZE)
    mini_stream_sector_count = len(mini_stream) // SECTOR_SIZE

    child_info: dict[int, tuple[list[tuple[int, int]], int]] = {}
    for node in ordered:
        if node.obj_type in (OBJ_STORAGE, OBJ_ROOT):
            child_info[node.dir_index] = rb_links(len(node.children))

    entries: list[bytes] = []
    for node in ordered:
        left, right = NOSTREAM, NOSTREAM
        child = NOSTREAM

        if node.obj_type in (OBJ_STORAGE, OBJ_ROOT):
            _, child_root_local = child_info[node.dir_index]
            if child_root_local != NOSTREAM:
                child = node.children[child_root_local].dir_index

        for storage_node, (pairs, _) in child_info.items():
            for i, c in enumerate(ordered[storage_node].children):
                if c is node:
                    lp, rp = pairs[i]
                    if lp != NOSTREAM:
                        left = ordered[storage_node].children[lp].dir_index
                    if rp != NOSTREAM:
                        right = ordered[storage_node].children[rp].dir_index
                    break

        if node.obj_type == OBJ_ROOT:
            start = 0
            size  = mini_stream_size
        elif node.obj_type == OBJ_STORAGE:
            start = 0
            size  = 0
        else:
            start = node.mini_start
            size  = len(node.payload)

        entries.append(build_dir_entry(
            node.name,
            node.obj_type,
            left=left,
            right=right,
            child=child,
            start_sector=start,
            size=size,
        ))

    dir_data = b"".join(entries)
    dir_data = pad_to(dir_data, SECTOR_SIZE)
    dir_sector_count = len(dir_data) // SECTOR_SIZE

    fat_sector_idx        = 0
    dir_start_idx         = 1
    mini_fat_start_idx    = dir_start_idx + dir_sector_count
    mini_stream_start_idx = mini_fat_start_idx + mini_fat_sector_count

    root_entry_bytes = bytearray(dir_data[0:DIR_ENTRY_SIZE])
    struct.pack_into("<I", root_entry_bytes, 116, mini_stream_start_idx)
    struct.pack_into("<Q", root_entry_bytes, 120, mini_stream_size)
    dir_data = bytes(root_entry_bytes) + dir_data[DIR_ENTRY_SIZE:]

    fat = [FREESECT] * (SECTOR_SIZE // 4)
    fat[fat_sector_idx] = FATSECT

    for i in range(dir_sector_count):
        s = dir_start_idx + i
        fat[s] = (dir_start_idx + i + 1) if i + 1 < dir_sector_count else ENDOFCHAIN

    for i in range(mini_fat_sector_count):
        s = mini_fat_start_idx + i
        fat[s] = (mini_fat_start_idx + i + 1) if i + 1 < mini_fat_sector_count else ENDOFCHAIN

    for i in range(mini_stream_sector_count):
        s = mini_stream_start_idx + i
        fat[s] = (mini_stream_start_idx + i + 1) if i + 1 < mini_stream_sector_count else ENDOFCHAIN

    fat_bytes = b"".join(struct.pack("<I", v) for v in fat)

    header = build_header(
        dir_start=dir_start_idx,
        fat_sectors=[fat_sector_idx],
        mini_fat_start=mini_fat_start_idx,
        mini_fat_count=mini_fat_sector_count,
    )

    Path(out_path).write_bytes(header + fat_bytes + dir_data + mini_fat_bytes + mini_stream)
    total = len(header) + len(fat_bytes) + len(dir_data) + len(mini_fat_bytes) + len(mini_stream)
    print(f"wrote {out_path} ({total} bytes, {len(ordered)} dir entries, "
          f"mini_stream_sectors={mini_stream_sector_count})")


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "Tests/EMLCoreTests/Fixtures/sample.msg"
    main(out)
