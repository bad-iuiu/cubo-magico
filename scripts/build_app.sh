#!/bin/zsh
# Compila e empacota o app em build/Cubo Mágico.app
set -e
cd "$(dirname "$0")/.."
swift build -c release --product CuboMagico
APP="build/Cubo Mágico.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/CuboMagico "$APP/Contents/MacOS/CuboMagico"

# Ícone
TMP=$(mktemp -d)
swift scripts/make_icon.swift "$TMP/icon.png"
mkdir "$TMP/AppIcon.iconset"
for s in 16 32 128 256 512; do
  sips -z $s $s "$TMP/icon.png" --out "$TMP/AppIcon.iconset/icon_${s}x${s}.png" >/dev/null
  sips -z $((s*2)) $((s*2)) "$TMP/icon.png" --out "$TMP/AppIcon.iconset/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$TMP/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$TMP"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Cubo Mágico</string>
  <key>CFBundleDisplayName</key><string>Cubo Mágico</string>
  <key>CFBundleIdentifier</key><string>com.iurerosa.cubomagico</string>
  <key>CFBundleExecutable</key><string>CuboMagico</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>CFBundleDevelopmentRegion</key><string>pt-BR</string>
</dict>
</plist>
PLIST
codesign --force --deep -s - "$APP"
echo "OK: $APP"
