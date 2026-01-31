#!/bin/bash

# Release script for AttentionApp
# Usage: ./scripts/release.sh [version]
# Example: ./scripts/release.sh 1.0.0

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
APP_DIR="$REPO_ROOT/AttentionApp"
BUILD_DIR="$APP_DIR/build"
RELEASE_DIR="$REPO_ROOT/releases"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get version from argument or prompt
VERSION=${1:-""}
if [ -z "$VERSION" ]; then
    echo -n "Enter version (e.g., 1.0.0): "
    read VERSION
fi

if [ -z "$VERSION" ]; then
    echo -e "${RED}Error: Version is required${NC}"
    exit 1
fi

echo -e "${GREEN}Building AttentionApp v$VERSION...${NC}"

# Build the app
cd "$APP_DIR"
./build-swiftc.sh

# Create releases directory
mkdir -p "$RELEASE_DIR"

# Create zip
echo -e "${GREEN}Creating zip archive...${NC}"
cd "$BUILD_DIR"
ZIP_NAME="AttentionApp-v$VERSION.zip"
rm -f "$ZIP_NAME"
zip -r "$ZIP_NAME" AttentionApp.app

# Calculate SHA256
echo -e "${GREEN}Calculating SHA256...${NC}"
SHA256=$(shasum -a 256 "$ZIP_NAME" | awk '{print $1}')

# Move to releases folder
mv "$ZIP_NAME" "$RELEASE_DIR/"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Release build complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "Version:  ${YELLOW}$VERSION${NC}"
echo -e "Zip file: ${YELLOW}$RELEASE_DIR/$ZIP_NAME${NC}"
echo -e "SHA256:   ${YELLOW}$SHA256${NC}"
echo ""
echo -e "${GREEN}Next steps:${NC}"
echo "1. Create a GitHub release at:"
echo "   https://github.com/YOURUSERNAME/attention-fix/releases/new"
echo ""
echo "2. Tag: v$VERSION"
echo ""
echo "3. Upload: $RELEASE_DIR/$ZIP_NAME"
echo ""
echo "4. Update your Homebrew cask with:"
echo ""
echo -e "${YELLOW}cask \"attentionapp\" do"
echo "  version \"$VERSION\""
echo "  sha256 \"$SHA256\""
echo ""
echo "  url \"https://github.com/YOURUSERNAME/attention-fix/releases/download/v#{version}/AttentionApp-v#{version}.zip\""
echo "  name \"AttentionApp\""
echo "  desc \"Play videos while waiting for builds\""
echo "  homepage \"https://github.com/YOURUSERNAME/attention-fix\""
echo ""
echo "  app \"AttentionApp.app\""
echo -e "end${NC}"
echo ""

# Save release info to file
INFO_FILE="$RELEASE_DIR/v$VERSION-info.txt"
cat > "$INFO_FILE" << EOF
AttentionApp v$VERSION Release Info
====================================
Date: $(date)
SHA256: $SHA256
Zip: $ZIP_NAME

Homebrew Cask:
--------------
cask "attentionapp" do
  version "$VERSION"
  sha256 "$SHA256"

  url "https://github.com/YOURUSERNAME/attention-fix/releases/download/v#{version}/AttentionApp-v#{version}.zip"
  name "AttentionApp"
  desc "Play videos while waiting for builds"
  homepage "https://github.com/YOURUSERNAME/attention-fix"

  app "AttentionApp.app"
end
EOF

echo -e "Release info saved to: ${YELLOW}$INFO_FILE${NC}"
