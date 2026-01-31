#!/bin/bash

# Setup Homebrew Tap for AttentionApp
# This creates the necessary files for a homebrew-tap repository

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
TAP_DIR="$REPO_ROOT/homebrew-tap"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}Setting up Homebrew tap structure...${NC}"

# Create directory structure
mkdir -p "$TAP_DIR/Casks"

# Create README
cat > "$TAP_DIR/README.md" << 'EOF'
# Homebrew Tap for AttentionApp

This is a Homebrew tap for [AttentionApp](https://github.com/dundeezhang/attention-fix).

## Installation

```bash
brew tap dundeezhang/tap https://github.com/dundeezhang/homebrew-tap
brew install --cask attentionapp
```

## Update

```bash
brew upgrade --cask attentionapp
```

## Uninstall

```bash
brew uninstall --cask attentionapp
```
EOF

# Create cask template
cat > "$TAP_DIR/Casks/attentionapp.rb" << 'EOF'
cask "attentionapp" do
  version "1.0.0"
  sha256 "REPLACE_WITH_SHA256"

  url "https://github.com/dundeezhang/attention-fix/releases/download/v#{version}/AttentionApp-v#{version}.zip"
  name "AttentionApp"
  desc "Play videos while waiting for builds"
  homepage "https://github.com/dundeezhang/attention-fix"

  depends_on macos: ">= :monterey"

  app "AttentionApp.app"

  zap trash: [
    "~/Library/Preferences/com.attentionapp.plist",
  ]
end
EOF

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Homebrew tap structure created!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "Location: ${YELLOW}$TAP_DIR${NC}"
echo ""
echo "Files created:"
echo "  - $TAP_DIR/README.md"
echo "  - $TAP_DIR/Casks/attentionapp.rb"
echo ""
echo -e "${GREEN}Next steps:${NC}"
echo "1. Update dundeezhang in the files with your GitHub username"
echo "2. Create a new GitHub repo named 'homebrew-tap'"
echo "3. Push the contents of $TAP_DIR to that repo:"
echo ""
echo "   cd $TAP_DIR"
echo "   git init"
echo "   git add ."
echo "   git commit -m 'Initial tap setup'"
echo "   git remote add origin https://github.com/dundeezhang/homebrew-tap.git"
echo "   git push -u origin main"
echo ""
echo "4. After creating a release, update Casks/attentionapp.rb with:"
echo "   - The correct version number"
echo "   - The SHA256 from the release script"
echo ""
