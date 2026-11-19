#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SDK_PATH=$(xcrun --sdk macosx --show-sdk-path 2>/dev/null || echo "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk")

echo "=========================================================="
echo " Compiling and Running UrbanDevicePOS Swift Test Suite"
echo "=========================================================="

swiftc -parse-as-library -sdk "$SDK_PATH" \
    "$DIR/Sources/Models.swift" \
    "$DIR/Sources/ThermalPrinter.swift" \
    "$DIR/Sources/POSViewModel.swift" \
    "$DIR/Sources/POSWindow.swift" \
    "$DIR/Sources/ContentView.swift" \
    "$DIR/Tests/POSTests.swift" \
    -o "$DIR/Tests/POSTestsRunner"

"$DIR/Tests/POSTestsRunner"
rm -f "$DIR/Tests/POSTestsRunner"
