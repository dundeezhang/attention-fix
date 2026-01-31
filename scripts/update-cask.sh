#!/bin/bash

# Update Homebrew Cask with new version and SHA256
# Usage: ./scripts/update-cask.sh <version> <sha256>
# Example: ./scripts/update-cask.sh 1.0.0 abc123...

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
CASK_FILE="$REPO_ROOT/homebrew-tap/Casks/attentionapp.rb"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

VERSION=$1
SHA256=$2

if [ -z "$VERSION" ] || [ -z "$SHA256" ]; then
    echo -e "${RED}Usage: $0 <version> <sha256>${NC}"
    echo "Example: $0 1.0.0 b455730b328ef42251c587b610472e8b39727f775ad71b02623af1f80d8326ca"
    exit 1
fi

if [ ! -f "$CASK_FILE" ]; then
    echo -e "${RED}Cask file not found at $CASK_FILE${NC}"
    echo "Run ./scripts/setup-homebrew-tap.sh first"
    exit 1
fi

echo -e "${GREEN}Updating cask to v$VERSION...${NC}"

# Update version
sed -i '' "s/version \".*\"/version \"$VERSION\"/" "$CASK_FILE"

# Update SHA256
sed -i '' "s/sha256 \".*\"/sha256 \"$SHA256\"/" "$CASK_FILE"

echo -e "${GREEN}Updated $CASK_FILE${NC}"
echo ""
cat "$CASK_FILE"
echo ""
echo -e "${GREEN}Don't forget to commit and push the changes to your homebrew-tap repo!${NC}"
