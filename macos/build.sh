#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
APP_BUNDLE="$DIR/UrbanDevicePOS.app"
ROOT_APP="$DIR/../UrbanDevicePOS.app"
SDK_PATH=$(xcrun --sdk macosx --show-sdk-path 2>/dev/null || echo "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk")

echo "=========================================================="
echo " Building Lightweight Native macOS App: UrbanDevicePOS.app"
echo " SDK: $SDK_PATH"
echo "=========================================================="

ARCH=$(uname -m)
echo "==> Compiling native Swift Mach-O binary with -O optimization for $ARCH..."
swiftc -parse-as-library -O -sdk "$SDK_PATH" "$DIR/Sources"/*.swift -o "$DIR/UrbanDevicePOS"

echo "==> Stripping binary symbols to achieve minimum binary footprint..."
strip -x "$DIR/UrbanDevicePOS"
BINARY_SIZE=$(ls -lh "$DIR/UrbanDevicePOS" | awk '{print $5}')
echo "==> Compiled Mach-O binary size: $BINARY_SIZE (100% native, 0 browser dependencies)"

# Assemble .app bundle directory layout
echo "==> Assembling .app bundle directory layout..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$DIR/UrbanDevicePOS" "$APP_BUNDLE/Contents/MacOS/UrbanDevicePOS"
chmod +x "$APP_BUNDLE/Contents/MacOS/UrbanDevicePOS"

if [ -f "$DIR/AppIcon.icns" ]; then
    cp "$DIR/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
fi

# Generate Info.plist
cat << 'EOF' > "$APP_BUNDLE/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleExecutable</key>
	<string>UrbanDevicePOS</string>
	<key>CFBundleIconFile</key>
	<string>AppIcon</string>
	<key>CFBundleIdentifier</key>
	<string>com.urbandevicecare.pos</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>Urban Device POS</string>
	<key>CFBundleDisplayName</key>
	<string>Urban Device POS</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>2.2.0</string>
	<key>CFBundleVersion</key>
	<string>3</string>
	<key>LSMinimumSystemVersion</key>
	<string>12.0</string>
	<key>NSHighResolutionCapable</key>
	<true/>
	<key>NSPrincipalClass</key>
	<string>NSApplication</string>
</dict>
</plist>
EOF

# Sign the app bundle
echo "==> Code signing UrbanDevicePOS.app..."
codesign --force --deep --sign - --identifier "com.urbandevicecare.pos" "$APP_BUNDLE"

# Mirror bundle to project root for instant Finder visibility
echo "==> Mirroring to workspace root for instant Finder access..."
rm -rf "$ROOT_APP"
cp -R "$APP_BUNDLE" "$ROOT_APP"
codesign --force --deep --sign - --identifier "com.urbandevicecare.pos" "$ROOT_APP"

echo "=========================================================="
echo " SUCCESS: Native macOS Mach-O App Ready!"
echo " Location: $APP_BUNDLE"
echo " Workspace Root: $ROOT_APP"
echo " Final Binary Size: $BINARY_SIZE"
echo "=========================================================="
