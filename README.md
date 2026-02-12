# AttentionApp

A macOS menu bar app that plays videos and images while you wait for builds, installs, and terminal commands to finish. Just for fun.

## Installation

### Download
Download the latest release from [Releases](https://github.com/dundeezhang/attention-fix/releases) and drag to Applications.

### Homebrew - currently broken
```bash
brew tap dundeezhang/tap
brew install --cask attentionapp
```

### Build from Source
```bash
./build-swiftc.sh
cp -r build/AttentionApp.app /Applications/
```

Requires macOS 12.0+ and Xcode Command Line Tools (`xcode-select --install`).

## Features

- **Auto-Detection** - Monitors for 50+ build tools and package managers
- **Media Support** - Videos (mp4, mov, mkv) and images (png, jpg, gif, webp)
- **DVD Bounce Mode** - Classic bouncing screensaver effect
- **Screensaver Mode** - Activates after configurable idle time
- **Multi-Video** - Display 1-4 videos at random positions
- **Loop Mode** - Keep the current video/image playing
- **Menu Bar App** - Lives in your menu bar, always accessible

## Supported Tools

**Package Managers:** npm, yarn, pnpm, bun, pip, cargo, brew, go, gem, composer, maven, gradle, dotnet, mix, pub, and more

**Compilers/Build Tools:** gcc, clang, make, cmake, rustc, swiftc, tsc, javac, and more

**Trigger Commands:** install, build, test, lint, update, clean, publish, etc.

**Ignored Commands:** start, dev, serve, watch, run, preview (long-running processes)

## Adding Media

1. Click the menu bar icon
2. Select "Open Media Folder..." or "Settings..."
3. Add your videos and images to the folder

Or use Settings to choose any folder on your Mac.

## Menu Options

- **Enabled** - Toggle monitoring on/off
- **DVD Bounce Mode** - Enable bouncing animation
- **Loop Current Video** - Keep current media playing
- **Screensaver Mode** - Auto-play after idle timeout
- **Video Count** - Number of simultaneous videos (1-4)
- **Test Video** - Preview your media
- **Settings** - Configure media folder and timeouts

## Settings

- **Media Folder** - Choose where to load videos/images from
- **Video Count** - How many videos to show at once
- **Screensaver Timeout** - Seconds of inactivity before screensaver starts

## Launch at Login

1. Open **System Settings** > **General** > **Login Items**
2. Click **+** under "Open at Login"
3. Select **AttentionApp** from Applications

## Project Structure

```
attention-fix/
├── AttentionApp/           # macOS app source
│   ├── AttentionApp/
│   │   ├── AppDelegate.swift
│   │   ├── ProcessMonitor.swift
│   │   ├── VideoPlayerWindow.swift
│   │   ├── SettingsWindow.swift
│   │   └── Resources/
│   └── build-swiftc.sh
├── attention-site/         # Landing page (Next.js)
├── scripts/                # Release scripts
└── README.md
```
