<p align="center">
  <img src="Resources/AppIcon.source.png" alt="EMLViewer" width="200">
</p>

# EMLViewer

Minimalist `.eml` viewer for macOS. Double-click an email in Finder — the window opens, renders the message and gets out of your way.
Built with Swift, SwiftUI, AppKit and WKWebView. Zero runtime dependencies.

## Features

- Parses `.eml` (RFC 822 / MIME) without third-party libraries
- Decoded headers: `From`, `To`, `Cc`, `Subject` (RFC 2047 encoded-words), `Date`
- HTML rendering via `WKWebView` with inline `cid:` images resolved from MIME parts
- Plain-text fallback for emails without an HTML part
- Attachments bar with Finder-style file icons; click to open in the default app, "Download All" to `~/Downloads`
- Works through Finder association: after a one-click `Set as default for .eml`, double-clicking a message just opens the window, reads the file, and shows it. No onboarding, no tray, no background daemon.
- Light / Dark / System appearance, window size persisted across launches (SwiftData)
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

- macOS 14.0+ (Sonoma or later — SwiftData)
- Swift 5.9+
- Xcode 15+ (or just the Swift CLI for SPM builds)
- For Xcode project regeneration: [`xcodegen`](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## Build

### Quick (SPM)

```bash
make bundle      # dist/EMLViewer.app (release, ad-hoc signed)
make install     # copy into /Applications
```

### Build + restart app (debug loop)

```bash
./Scripts/build.sh          # debug: kills the running instance, rebuilds, opens the new .app
./Scripts/build.sh release  # same but release config
# or
make run                    # alias for ./Scripts/build.sh debug
```

### Xcode project (for App Store / signed archive)

The Xcode project is generated from `project.yml`:

```bash
xcodegen generate
open EMLViewer.xcodeproj
# or build from CLI:
xcodebuild -project EMLViewer.xcodeproj -scheme EMLViewer -configuration Release build
```

## Test

```bash
make test              # swift test (SPM)
xcodebuild -project EMLViewer.xcodeproj -scheme EMLViewer test
```

## License

MIT
