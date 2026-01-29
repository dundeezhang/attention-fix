#!/bin/bash

# Build AttentionApp

cd "$(dirname "$0")"

echo "Building AttentionApp..."

xcodebuild -project AttentionApp.xcodeproj \
    -scheme AttentionApp \
    -configuration Release \
    -derivedDataPath build \
    build

if [ $? -eq 0 ]; then
    echo ""
    echo "Build successful!"
    echo "App location: $(pwd)/build/Build/Products/Release/AttentionApp.app"
    echo ""
    echo "To install to Applications:"
    echo "  cp -r build/Build/Products/Release/AttentionApp.app /Applications/"
    echo ""
    echo "To run directly:"
    echo "  open build/Build/Products/Release/AttentionApp.app"
else
    echo "Build failed!"
    exit 1
fi
