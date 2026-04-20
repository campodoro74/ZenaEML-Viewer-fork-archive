#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

: "${ASC_KEY_PATH:?ASC_KEY_PATH must point to .p8 API key file}"
: "${ASC_KEY_ID:?ASC_KEY_ID must be set (10 chars)}"
: "${ASC_ISSUER_ID:?ASC_ISSUER_ID must be set (UUID)}"

export ASC_KEY_PATH ASC_KEY_ID ASC_ISSUER_ID
TEAM="${TEAM:-89QF7X66FR}"
ARCHIVE_PATH="build/EMLViewer.xcarchive"
EXPORT_DIR="build/export"
EXPORT_OPTS="build/ExportOptions.plist"

echo "==> ensure App ID + Mac App Store provisioning profile"
PROFILE_NAME=$(python3 Scripts/asc-profile.py | tail -1)
echo "    profile: $PROFILE_NAME"

echo "==> xcodebuild archive (manual signing, Apple Distribution)"
rm -rf "$ARCHIVE_PATH" "$EXPORT_DIR"
xcodebuild archive \
  -project EMLViewer.xcodeproj \
  -scheme EMLViewer \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath "$ARCHIVE_PATH" \
  DEVELOPMENT_TEAM="$TEAM"

echo "==> write ExportOptions.plist"
mkdir -p build
cat > "$EXPORT_OPTS" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>app-store-connect</string>
  <key>teamID</key><string>${TEAM}</string>
  <key>signingStyle</key><string>manual</string>
  <key>signingCertificate</key><string>Apple Distribution</string>
  <key>installerSigningCertificate</key><string>3rd Party Mac Developer Installer</string>
  <key>destination</key><string>upload</string>
  <key>uploadSymbols</key><true/>
  <key>provisioningProfiles</key>
  <dict>
    <key>com.noma4i.EMLViewer</key>
    <string>${PROFILE_NAME}</string>
  </dict>
</dict></plist>
EOF

echo "==> xcodebuild -exportArchive (uploads to TestFlight)"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$EXPORT_OPTS" \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$ASC_KEY_PATH" \
  -authenticationKeyID "$ASC_KEY_ID" \
  -authenticationKeyIssuerID "$ASC_ISSUER_ID"

echo ""
echo "Done. Build uploaded. Check App Store Connect → TestFlight in a few minutes."
