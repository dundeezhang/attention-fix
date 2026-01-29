#!/bin/bash

# Build AttentionApp using swiftc directly (no Xcode required)

cd "$(dirname "$0")"

APP_NAME="AttentionApp"
BUILD_DIR="build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

# Clean previous build
rm -rf "$BUILD_DIR"

# Create app bundle structure
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

echo "Compiling Swift files..."

# Compile all Swift files
swiftc \
    -o "$MACOS_DIR/$APP_NAME" \
    -target arm64-apple-macosx12.0 \
    -sdk $(xcrun --show-sdk-path) \
    -framework AppKit \
    -framework AVKit \
    -framework AVFoundation \
    -framework SwiftUI \
    -O \
    AttentionApp/*.swift

if [ $? -ne 0 ]; then
    echo "Compilation failed!"
    exit 1
fi

# Copy Info.plist
cp AttentionApp/Info.plist "$CONTENTS_DIR/"

# Copy Resources (including test.mp4)
cp -r AttentionApp/Resources/* "$RESOURCES_DIR/" 2>/dev/null || true

# Create PkgInfo
echo -n "APPL????" > "$CONTENTS_DIR/PkgInfo"

echo ""
echo "Build successful!"
echo "App location: $(pwd)/$APP_BUNDLE"
echo ""
echo "To install to Applications:"
echo "  cp -r $APP_BUNDLE /Applications/"
echo ""
echo "To run directly:"
echo "  open $APP_BUNDLE"
