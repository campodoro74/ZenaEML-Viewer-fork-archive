<p align="center">
  <img src="Resources/AppIcon.source.png" alt="EMLViewer" width="200">
</p>

# EMLViewer

Minimalist `.eml` viewer for macOS. Double-click an email file in Finder — see it.
Built with Swift, SwiftUI, AppKit and WKWebView. No Electron, no dependencies.

## Features

- Parses `.eml` (RFC 822 / MIME) without third-party libraries
- Decoded headers: `From`, `To`, `Cc`, `Subject` (RFC 2047 encoded-words), `Date`
- HTML rendering via `WKWebView` with inline `cid:` images resolved from MIME parts
- Plain-text fallback for emails without an HTML part
- Attachments bar with real system file icons; click to open, "Download All" to `~/Downloads`
- Welcome screen with one-click "Set as default for `.eml` files"
- Drag-and-drop support and CLI opening (`open -a EMLViewer file.eml`)
- `emlcheck` CLI companion for inspecting MIME trees from the terminal

## Install

### Homebrew

```bash
brew tap noma4i/emlviewer https://github.com/noma4i/emlviewer
brew install --cask emlviewer
```

### Download

Grab the latest `EMLViewer.app.zip` from [Releases](https://github.com/noma4i/emlviewer/releases).

## Requirements

- macOS 13.0+ (Ventura or later)
- Swift 5.9+
- Xcode 15+ (for `swift` CLI and `WebKit`/`SwiftUI` frameworks)

## Build

```bash
make bundle     # Release .app in dist/EMLViewer.app
make install    # Copy into /Applications
```

## Run

```bash
make run            # Debug build + launch
make cli FILE=x.eml # Dump MIME tree of a .eml via emlcheck
```

## Test

```bash
make test
```

## License

MIT
