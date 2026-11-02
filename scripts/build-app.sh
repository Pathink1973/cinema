#!/bin/zsh
set -eu
cd "$(dirname "$0")/.."
swift build -c release
BIN_DIR=$(swift build -c release --show-bin-path)
APP="$PWD/dist/Cinema.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/Cinema" "$APP/Contents/MacOS/Cinema"
cp "$PWD/assets/Cinema.icns" "$APP/Contents/Resources/Cinema.icns"
for resource in "$BIN_DIR"/*.bundle(N); do cp -R "$resource" "$APP/Contents/Resources/"; done
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>Cinema</string>
<key>CFBundleIdentifier</key><string>pt.local.cinema</string>
<key>CFBundleIconFile</key><string>Cinema.icns</string>
<key>CFBundleName</key><string>Cinema</string>
<key>CFBundleDisplayName</key><string>Cinema</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSLocalNetworkUsageDescription</key><string>Partilhar o filme escolhido com o VLC do iPhone na mesma rede Wi-Fi.</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --deep --sign - "$APP"
echo "$APP"
