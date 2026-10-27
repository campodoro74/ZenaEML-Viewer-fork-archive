<p align="center">
  <img src="Resources/AppIcon.source.png" alt="ZenaEML Viewer" width="180">
</p>

# ZenaEML Viewer

ZenaConsult macOS viewer for `.eml` / `.emlx` / `.msg` with Finder **Quick Look**. Based on the MIT [EMLViewer](https://github.com/noma4i/emlviewer) project.

**GitHub:** [campodoro74/ZenaEML-Viewer](https://github.com/campodoro74/ZenaEML-Viewer)

| | |
| --- | --- |
| Display name | ZenaEML Viewer |
| Bundle id | `it.zenaconsult.ZenaEMLViewer` |
| Quick Look | `it.zenaconsult.ZenaEMLViewer.QuickLook` |
| Team | `P675R8Z5DF` |
| Notarization Apple ID | `dev@zenaconsult.com` |

## Features

- Open `.eml` / `.emlx` / `.msg` without Mail or Outlook
- Finder Space-bar Quick Look (headers + body + attachments)
- Default document handler (`LSHandlerRank` Owner)
- Universal binary, macOS 14+

## Ecotrade install

See [docs/ECOTRADE-INSTALL.md](docs/ECOTRADE-INSTALL.md). Signed builds land in `~/Documents/Agent/exports/emlviewer/`.

```bash
sudo bash Scripts/install-ecotrade.sh /path/to/EMLViewer.app
```

## Build

Derived data stays under `/tmp` (iCloud xattrs break `codesign`).

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
bash Scripts/build.sh debug --open
bash Scripts/build.sh release --developer-id
```

### Notarized DMG

```bash
xcrun notarytool store-credentials zenaconsult \
  --apple-id "dev@zenaconsult.com" \
  --team-id "P675R8Z5DF" \
  --password "<app-specific-password>"

bash Scripts/distribute-developer-id.sh
```

## Test

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -project EMLViewer.xcodeproj -scheme EMLViewer \
  -destination 'platform=macOS' -derivedDataPath /tmp/emlviewer-dd test
```

## License

MIT (upstream EMLViewer + ZenaConsult modifications)
