#!/bin/bash

# Creates an .icns file from a source image (PNG recommended, at least 1024x1024)
# Usage: ./create-icon.sh /path/to/your/image.png

set -e

if [ -z "$1" ]; then
    echo "Usage: ./create-icon.sh /path/to/image.png"
    echo ""
    echo "Provide a PNG image (1024x1024 recommended)"
    exit 1
fi

SOURCE_IMAGE="$1"
ICONSET_DIR="AppIcon.iconset"
OUTPUT_DIR="AttentionApp/Resources"

# Check if source exists
if [ ! -f "$SOURCE_IMAGE" ]; then
    echo "Error: File not found: $SOURCE_IMAGE"
    exit 1
fi

# Create iconset directory
rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"

# Generate all required sizes
echo "Generating icon sizes..."
sips -z 16 16     "$SOURCE_IMAGE" --out "$ICONSET_DIR/icon_16x16.png" > /dev/null
sips -z 32 32     "$SOURCE_IMAGE" --out "$ICONSET_DIR/icon_16x16@2x.png" > /dev/null
sips -z 32 32     "$SOURCE_IMAGE" --out "$ICONSET_DIR/icon_32x32.png" > /dev/null
sips -z 64 64     "$SOURCE_IMAGE" --out "$ICONSET_DIR/icon_32x32@2x.png" > /dev/null
sips -z 128 128   "$SOURCE_IMAGE" --out "$ICONSET_DIR/icon_128x128.png" > /dev/null
sips -z 256 256   "$SOURCE_IMAGE" --out "$ICONSET_DIR/icon_128x128@2x.png" > /dev/null
sips -z 256 256   "$SOURCE_IMAGE" --out "$ICONSET_DIR/icon_256x256.png" > /dev/null
sips -z 512 512   "$SOURCE_IMAGE" --out "$ICONSET_DIR/icon_256x256@2x.png" > /dev/null
sips -z 512 512   "$SOURCE_IMAGE" --out "$ICONSET_DIR/icon_512x512.png" > /dev/null
sips -z 1024 1024 "$SOURCE_IMAGE" --out "$ICONSET_DIR/icon_512x512@2x.png" > /dev/null

# Convert to icns
echo "Creating .icns file..."
iconutil -c icns "$ICONSET_DIR" -o "$OUTPUT_DIR/AppIcon.icns"

# Cleanup
rm -rf "$ICONSET_DIR"

echo "Done! Icon created at $OUTPUT_DIR/AppIcon.icns"
echo "Rebuild the app with ./build-swiftc.sh"
