# Changelog

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
