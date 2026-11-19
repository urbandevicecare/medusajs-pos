#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export ANDROID_HOME="${ANDROID_HOME:-/Users/slyb./Library/Android/sdk}"

echo "=========================================================="
echo " Building 100% Native Android App for CS30 Smart POS"
echo " (Zero Capacitor / Zero WebView bloat)"
echo " Android SDK: $ANDROID_HOME"
echo "=========================================================="

cd "$DIR"

# 1. Run unit tests
echo "==> Running native Android unit tests..."
./gradlew test --info

# 2. Build release APK with R8/ProGuard minification
echo "==> Compiling optimized release APK..."
./gradlew assembleRelease

APK_SRC=$(find app/build/outputs/apk/release -name "*.apk" | head -n 1)

if [ -f "$APK_SRC" ]; then
    cp "$APK_SRC" "$DIR/UrbanDevicePOS.apk"
    cp "$APK_SRC" "$DIR/../UrbanDevicePOS.apk"
    APK_SIZE=$(ls -lh "$DIR/UrbanDevicePOS.apk" | awk '{print $5}')
    echo "=========================================================="
    echo " SUCCESS: Native Android CS30 APK Built!"
    echo " Location: $DIR/UrbanDevicePOS.apk"
    echo " Workspace Root: $DIR/../UrbanDevicePOS.apk"
    echo " Final APK Size: $APK_SIZE (100% native Kotlin/Java, 0 WebView)"
    echo "=========================================================="
else
    echo "Error: Release APK not found at $APK_SRC"
    exit 1
fi
