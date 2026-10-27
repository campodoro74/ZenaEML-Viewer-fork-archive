# Changelog

## [1.1.0] - 2026-10-27

### Added

- Quick Look Preview Extension (`EMLViewerQuickLook.appex`) for `.eml` / `.emlx` / `.msg` (Finder Space bar).
- Shared `PreviewHTML` builder in `EMLCore` (headers, sanitized HTML/plain body, `cid:` → QL attachments).
- Developer ID + notarization scripts (`Scripts/distribute-developer-id.sh`, `Scripts/install-ecotrade.sh`).
- Ecotrade install notes in `docs/ECOTRADE-INSTALL.md`.

### Changed

- Product rebranded to **ZenaEML Viewer** (ZenaConsult); GitHub home [campodoro74/ZenaEML-Viewer](https://github.com/campodoro74/ZenaEML-Viewer).
- App icon uses the ZenaConsult shield (`logo-icon.png`).
- Bundle identifiers → `it.zenaconsult.ZenaEMLViewer` / `.QuickLook` (Team `P675R8Z5DF`).
- Document handler rank → `Owner` for email / Outlook message UTIs.
- Release build uses Developer ID entitlements (hardened runtime); derived data under `/tmp` to avoid iCloud xattr codesign failures.

## [1.0.0] - 2026-04-16

### Added

- Initial release of EMLViewer, a minimalist `.eml` and `.msg` viewer for macOS.
- MIME parser with RFC 2047 encoded-word, quoted-printable, base64, and charset decoding (UTF-8, Windows-125x, ISO-8859-\*).
- Nested `multipart/mixed`, `multipart/related`, and `multipart/alternative` support; inline image resolution via `cid:` URL scheme.
- Outlook `.msg` (Compound File Binary) support via a native CFB/MAPI reader, no external dependencies. Subject, sender, recipients and plain body are decoded from MAPI property streams.
- Finder association for both `.eml` and `.msg`, with a one-click Welcome action that registers EMLViewer as the default handler.
- SwiftUI UI: decoded headers, `WKWebView` HTML rendering, horizontal attachments bar with system file icons.
- Attachment actions: click to open in the associated app, "Download All" to `~/Downloads`, context menu "Save As...".
- Welcome screen with appearance picker (System / Light / Dark), GitHub button, version info.
- Light / Dark / System theme picker with persistence across app launches.
- Window size persisted across launches via SwiftData.
- Hidden title bar for a lighter look.
- `emlcheck` CLI companion that prints MIME tree, inline parts, and attachments.
- Makefile targets (`build`, `run`, `bundle`, `zip`, `install`, `test`, `icon`), ad-hoc signing, LaunchServices registration.
