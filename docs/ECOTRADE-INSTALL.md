# ZenaEML Viewer — Ecotrade iMac install

ZenaConsult app with Finder Quick Look for `.eml` / `.emlx` / `.msg`.

## Package

- App bundle (build product): `EMLViewer.app` — Finder shows **ZenaEML Viewer**
- Bundle id: `it.zenaconsult.ZenaEMLViewer`
- Quick Look: `…/PlugIns/EMLViewerQuickLook.appex` (`it.zenaconsult.ZenaEMLViewer.QuickLook`)
- Signed: Developer ID Application — Martijn Goudkamp (`P675R8Z5DF`)
- Notarized when built with `Scripts/distribute-developer-id.sh`

## Install (each iMac)

1. Open the notarized `EMLViewer-*.dmg` (or `ZenaEML-Viewer-*.dmg` when renamed).
2. Drag the app into **Applications** (install script places it as `ZenaEML Viewer.app`).
3. Open once (right‑click → Open only if Gatekeeper still prompts on an unnotarized build).
4. Welcome screen → **Set as default for .eml and .msg**.
5. Enable Quick Look if Space bar still shows Mail’s weak preview:
   - **System Settings → General → Login Items & Extensions → Quick Look**
   - Turn on **ZenaEML Viewer Quick Look**
   - If needed, temporarily disable Apple Mail / Letter Opener Quick Look entries

## Verify

| Check | How |
| --- | --- |
| Double‑click `.eml` | Opens ZenaEML Viewer with headers + body |
| Space on `.eml` | Quick Look shows subject, from/to, body |
| Outlook CRLF export | Body still visible |
| `.msg` | Double‑click + Space both work |

## Scripted install

```bash
sudo bash Scripts/install-ecotrade.sh /path/to/EMLViewer.app
```

Optional (`duti`):

```bash
duti -s it.zenaconsult.ZenaEMLViewer public.email-message all
duti -s it.zenaconsult.ZenaEMLViewer com.microsoft.outlook-email-message all
```

## Uninstall

```bash
rm -rf "/Applications/ZenaEML Viewer.app" "/Applications/EMLViewer.app"
defaults delete it.zenaconsult.ZenaEMLViewer 2>/dev/null || true
```

## Rebuild (Zena)

```bash
cd ~/Documents/Agent/emlviewer
bash Scripts/distribute-developer-id.sh
```

Repo: https://github.com/campodoro74/ZenaEML-Viewer
