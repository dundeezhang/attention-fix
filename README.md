# AttentionApp

A macOS status bar app that plays a random video whenever it detects npm/pnpm/yarn/bun commands running (install, build, lint, test, etc.). The video automatically closes when the command finishes.

## Features

- Lives in the menu bar with an eye icon
- Monitors for package manager commands every 0.5 seconds
- Plays a random video from the bundled collection
- Video starts at a random point (10-20 seconds in) for variety
- Auto-closes when the command completes
- Native macOS window controls (traffic lights)
- Stays above all other windows

## Triggers

**Commands that show the video:**
- install, add, i
- build, compile
- lint, eslint, prettier
- test, jest, vitest, mocha
- update, upgrade
- clean, clear, cache
- audit, outdated
- publish, pack
- init, create
- ci, dedupe, prune
- remove, uninstall
- link, unlink
- exec, dlx, npx

**Commands that are ignored:**
- start, dev, serve, watch, run, preview, storybook

## Requirements

- macOS 12.0 or later
- Xcode Command Line Tools (`xcode-select --install`)

## Adding Videos

Place your video files (mp4, mov, m4v, avi, mkv) in:

```
AttentionApp/Resources/
```

The app will randomly select one each time it triggers.

## Build

```bash
./build-swiftc.sh
```

The built app will be at `build/AttentionApp.app`

## Run

```bash
open build/AttentionApp.app
```

## Install to Applications

```bash
cp -r build/AttentionApp.app /Applications/
```

Then launch from Spotlight or Applications folder.

## Menu Options

Click the eye icon in the menu bar:

- **Enabled** - Toggle monitoring on/off
- **Test Video** - Manually trigger a video (auto-closes after 5 seconds)
- **Quit** - Exit the app

## Launch at Login

1. Open **System Settings** > **General** > **Login Items**
2. Click **+** under "Open at Login"
3. Select **AttentionApp** from Applications

## Project Structure

```
AttentionApp/
├── AttentionApp/
│   ├── AttentionAppApp.swift    # App entry point
│   ├── AppDelegate.swift        # Status bar and video control
│   ├── ProcessMonitor.swift     # Detects package manager commands
│   ├── VideoPlayerWindow.swift  # Floating video player
│   ├── Info.plist
│   ├── AttentionApp.entitlements
│   └── Resources/               # Video files go here
├── AttentionApp.xcodeproj/      # Xcode project (optional)
├── build-swiftc.sh              # Build script
├── build.sh                     # Xcode build script (requires full Xcode)
└── README.md
```
