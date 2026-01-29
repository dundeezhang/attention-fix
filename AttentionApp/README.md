# AttentionApp

A macOS menu bar app that plays videos or shows images while you wait for builds, installs, and AI tools to finish processing.

## Features

### Build & Package Manager Detection
Automatically detects and triggers on:
- **JavaScript/Node:** npm, pnpm, yarn, bun
- **Python:** pip, pip3, pipx, uv, poetry, pdm, conda, mamba
- **Rust:** cargo, rustup, rustc
- **Go:** go build/install/get/mod/test
- **Ruby:** gem, bundle
- **PHP:** composer
- **Java:** mvn, gradle
- **.NET:** dotnet, nuget
- **macOS:** brew install/upgrade/update
- **Swift:** swift build/test/package, swiftc
- **C/C++:** gcc, g++, clang, make, cmake, ninja, vcpkg, conan
- **And many more:** Elixir, Haskell, Nim, Dart, Zig, etc.

### AI Tool Monitoring
Detects when AI coding assistants are "thinking" (actively processing):
- **Claude Code** - Anthropic's CLI tool
- **Cursor** - AI-powered IDE
- **GitHub Copilot**
- **Codeium**
- **Tabnine**

The video plays while the AI is generating responses and stops when it's waiting for your input.

### Media Support
- **Videos:** mp4, mov, m4v, avi, mkv, webm
- **Images:** png, jpg, jpeg, heic, heif, gif, webp, bmp, tiff

Place media files in the `AttentionApp/Resources/` folder or `~/Movies/`.

### Menu Bar Options
- **Enabled** (⌘E) - Toggle monitoring on/off
- **DVD Bounce Mode** (⌘B) - Window bounces around screen like classic DVD screensaver
- **Loop Current Video** (⌘L) - Keep playing the same video/image instead of shuffling
- **Test Video** (⌘T) - Toggle video display for testing
- **Previous Video** (⌘[) - Go back to previously played media
- **Next Video** (⌘]) - Skip to next random media
- **Quit** (⌘Q)

### Persisted Settings
The following settings are saved between app launches:
- DVD Bounce Mode
- Loop Current Video

## Installation

### Build from Source
```bash
./build-swiftc.sh
cp -r build/AttentionApp.app /Applications/
```

### Add Custom Icon
```bash
./create-icon.sh /path/to/your/icon.png
./build-swiftc.sh
cp -r build/AttentionApp.app /Applications/
```

### Launch at Login
1. Open **System Settings** > **General** > **Login Items**
2. Click **+** under "Open at Login"
3. Select **AttentionApp** from Applications

## Adding Media

Place video or image files in:
- `AttentionApp/Resources/` (bundled with app)
- `~/Movies/` (fallback location)
- `~/Desktop/` (fallback location)
- `~/Downloads/` (fallback location)

The app randomly selects media and automatically advances to the next item when:
- A video ends
- An image has been displayed for 8 seconds

## Window Behavior

- Floats above all windows
- Appears on all desktops/spaces
- Ignored by tiling window managers (yabai, Amethyst, etc.)
- Doesn't appear in macOS media controls
- Doesn't steal focus from other apps

## License

MIT
