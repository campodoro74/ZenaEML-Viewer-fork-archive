# Changelog

## [1.0.0] - 2026-04-16

### Added
- Initial release of EMLViewer, a minimalist `.eml` viewer for macOS.
- MIME parser with RFC 2047 encoded-word, quoted-printable, base64, and charset decoding (UTF-8, Windows-125x, ISO-8859-*).
- Nested `multipart/mixed`, `multipart/related`, and `multipart/alternative` support; inline image resolution via `cid:` URL scheme.
- SwiftUI UI: decoded headers, `WKWebView` HTML rendering, horizontal attachments bar with system file icons.
- Attachment actions: click to open in the associated app, "Download All" to `~/Downloads`, context menu "Save As…".
- Welcome screen with "Set as default for .eml" via `NSWorkspace.setDefaultApplication(at:toOpen:)`, GitHub button, version info.
- Hidden title bar for a lighter look.
- `emlcheck` CLI companion that prints MIME tree, inline parts, and attachments.
- Makefile targets (`build`, `run`, `bundle`, `zip`, `install`, `test`, `icon`), ad-hoc signing, LaunchServices registration.
