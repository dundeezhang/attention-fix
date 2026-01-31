import AppKit
import IOKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var processMonitor: ProcessMonitor!
    private var videoWindows: [VideoPlayerWindow] = []
    private var settingsWindow: SettingsWindow?
    private var isEnabled = true
    private var isBounceMode = false
    private var isLoopMode = false
    private var isTestMode = false
    private var isScreensaverMode = false
    private var isScreensaverActive = false
    private var videoCount = 1
    private var activeProcesses: Set<pid_t> = []

    // Screensaver
    private var idleTimer: Timer?
    private var globalEventMonitor: Any?
    private var localEventMonitor: Any?

    private let bounceModeKey = "AttentionApp.BounceMode"
    private let loopModeKey = "AttentionApp.LoopMode"
    private let screensaverModeKey = "AttentionApp.ScreensaverMode"
    private let videoCountKey = "AttentionApp.VideoCount"

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Load saved preferences
        isBounceMode = UserDefaults.standard.bool(forKey: bounceModeKey)
        isLoopMode = UserDefaults.standard.bool(forKey: loopModeKey)
        isScreensaverMode = UserDefaults.standard.bool(forKey: screensaverModeKey)
        videoCount = max(1, UserDefaults.standard.integer(forKey: videoCountKey))
        if videoCount == 0 { videoCount = 1 }

        setupStatusBar()
        setupProcessMonitor()

        if isScreensaverMode {
            startIdleMonitoring()
        }
    }

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "eye.fill", accessibilityDescription: "Attention")
            button.image?.isTemplate = true
        }

        let menu = NSMenu()

        let enableItem = NSMenuItem(title: "Enabled", action: #selector(toggleEnabled), keyEquivalent: "")
        enableItem.state = isEnabled ? .on : .off
        menu.addItem(enableItem)

        let bounceItem = NSMenuItem(title: "DVD Bounce Mode", action: #selector(toggleBounceMode), keyEquivalent: "")
        bounceItem.state = isBounceMode ? .on : .off
        menu.addItem(bounceItem)

        let loopItem = NSMenuItem(title: "Loop Current Video", action: #selector(toggleLoopMode), keyEquivalent: "")
        loopItem.state = isLoopMode ? .on : .off
        menu.addItem(loopItem)

        let screensaverItem = NSMenuItem(title: "Screensaver Mode", action: #selector(toggleScreensaverMode), keyEquivalent: "")
        screensaverItem.state = isScreensaverMode ? .on : .off
        menu.addItem(screensaverItem)

        // Video Count Submenu
        let videoCountItem = NSMenuItem(title: "Video Count", action: nil, keyEquivalent: "")
        let videoCountMenu = NSMenu()
        for count in 1...4 {
            let item = NSMenuItem(title: "\(count)", action: #selector(setVideoCount(_:)), keyEquivalent: "")
            item.tag = count
            item.state = videoCount == count ? .on : .off
            videoCountMenu.addItem(item)
        }
        videoCountItem.submenu = videoCountMenu
        menu.addItem(videoCountItem)

        menu.addItem(NSMenuItem.separator())

        let testItem = NSMenuItem(title: "Test Video", action: #selector(toggleTestVideo), keyEquivalent: "")
        testItem.state = isTestMode ? .on : .off
        menu.addItem(testItem)

        menu.addItem(NSMenuItem(title: "Stop All Videos", action: #selector(forceStopAllVideos), keyEquivalent: ""))

        menu.addItem(NSMenuItem.separator())

        // Media controls on one line with icons
        let mediaItem = NSMenuItem()
        mediaItem.view = createMediaControls()
        menu.addItem(mediaItem)

        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Open Media Folder...", action: #selector(openMediaFolder), keyEquivalent: ""))

        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: ""))

        statusItem.menu = menu
    }

    private func setupProcessMonitor() {
        processMonitor = ProcessMonitor(
            onCommandDetected: { [weak self] command, pid in
                DispatchQueue.main.async {
                    self?.handleCommandStarted(command: command, pid: pid)
                }
            },
            onCommandFinished: { [weak self] pid in
                DispatchQueue.main.async {
                    self?.handleCommandFinished(pid: pid)
                }
            }
        )
        processMonitor.startMonitoring()
    }

    // MARK: - Idle/Screensaver Monitoring

    private func startIdleMonitoring() {
        stopIdleMonitoring()

        // Check idle time every second
        idleTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkIdleTime()
        }

        // Monitor for activity to dismiss screensaver (global - other apps)
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .keyDown, .leftMouseDown, .rightMouseDown, .scrollWheel]) { [weak self] _ in
            self?.handleUserActivity()
        }

        // Monitor for activity to dismiss screensaver (local - this app)
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .keyDown, .leftMouseDown, .rightMouseDown, .scrollWheel]) { [weak self] event in
            self?.handleUserActivity()
            return event
        }
    }

    private func stopIdleMonitoring() {
        idleTimer?.invalidate()
        idleTimer = nil

        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
            globalEventMonitor = nil
        }

        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }
    }

    private func checkIdleTime() {
        let idleSeconds = getSystemIdleTime()
        let timeout = SettingsWindow.getScreensaverTimeout()

        if idleSeconds >= timeout && !isScreensaverActive {
            activateScreensaver()
        }
    }

    private func getSystemIdleTime() -> Double {
        var iterator: io_iterator_t = 0
        defer { IOObjectRelease(iterator) }

        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOHIDSystem"), &iterator) == KERN_SUCCESS else {
            return 0
        }

        let entry = IOIteratorNext(iterator)
        defer { IOObjectRelease(entry) }

        guard entry != 0 else { return 0 }

        var unmanagedDict: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(entry, &unmanagedDict, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let dict = unmanagedDict?.takeRetainedValue() as? [String: Any],
              let idleTime = dict["HIDIdleTime"] as? Int64 else {
            return 0
        }

        // HIDIdleTime is in nanoseconds
        return Double(idleTime) / 1_000_000_000.0
    }

    private func activateScreensaver() {
        guard !isScreensaverActive else { return }
        isScreensaverActive = true

        // Show video with DVD bounce mode
        let targetCount = SettingsWindow.getVideoCount()
        videoWindows.removeAll()
        for i in 0..<targetCount {
            let window = VideoPlayerWindow(randomStart: i > 0 || targetCount > 1)
            window.setBounceMode(true)
            window.setLoopMode(true)
            window.showAndPlay()
            videoWindows.append(window)
        }
    }

    private func handleUserActivity() {
        guard isScreensaverActive else { return }
        deactivateScreensaver()
    }

    private func deactivateScreensaver() {
        guard isScreensaverActive else { return }
        isScreensaverActive = false

        // Always hide when deactivating screensaver, unless there's an active build
        cleanupStaleProcesses()
        if activeProcesses.isEmpty && !isTestMode {
            hideVideoPlayer()
        } else {
            // Restore normal settings
            videoWindows.forEach {
                $0.setBounceMode(isBounceMode)
                $0.setLoopMode(isLoopMode)
            }
        }
    }

    // Force stop all videos (emergency stop)
    @objc private func forceStopAllVideos() {
        isScreensaverActive = false
        isTestMode = false
        activeProcesses.removeAll()
        hideVideoPlayer()

        // Update menu item states
        if let menu = statusItem.menu {
            for item in menu.items {
                if item.title == "Test Video" {
                    item.state = .off
                }
            }
        }
    }

    // MARK: - Menu Actions

    @objc private func toggleEnabled(_ sender: NSMenuItem) {
        isEnabled.toggle()
        sender.state = isEnabled ? .on : .off

        if isEnabled {
            processMonitor.startMonitoring()
        } else {
            processMonitor.stopMonitoring()
            activeProcesses.removeAll()
            hideVideoPlayer()
        }
    }

    @objc private func toggleBounceMode(_ sender: NSMenuItem) {
        isBounceMode.toggle()
        sender.state = isBounceMode ? .on : .off
        videoWindows.forEach { $0.setBounceMode(isBounceMode) }

        // Save preference
        UserDefaults.standard.set(isBounceMode, forKey: bounceModeKey)
    }

    @objc private func toggleLoopMode(_ sender: NSMenuItem) {
        isLoopMode.toggle()
        sender.state = isLoopMode ? .on : .off
        videoWindows.forEach { $0.setLoopMode(isLoopMode) }

        // Save preference
        UserDefaults.standard.set(isLoopMode, forKey: loopModeKey)
    }

    @objc private func toggleScreensaverMode(_ sender: NSMenuItem) {
        isScreensaverMode.toggle()
        sender.state = isScreensaverMode ? .on : .off

        if isScreensaverMode {
            startIdleMonitoring()
        } else {
            stopIdleMonitoring()
            if isScreensaverActive {
                deactivateScreensaver()
            }
        }

        // Save preference
        UserDefaults.standard.set(isScreensaverMode, forKey: screensaverModeKey)
    }

    @objc private func setVideoCount(_ sender: NSMenuItem) {
        videoCount = sender.tag
        UserDefaults.standard.set(videoCount, forKey: videoCountKey)

        // Update menu checkmarks
        if let menu = sender.menu {
            for item in menu.items {
                item.state = item.tag == videoCount ? .on : .off
            }
        }

        // If currently showing, recreate windows with new count
        if !videoWindows.isEmpty && videoWindows.first?.isVisible == true {
            hideVideoPlayer()
            showVideoPlayer()
        }
    }

    @objc private func toggleTestVideo(_ sender: NSMenuItem) {
        isTestMode.toggle()
        sender.state = isTestMode ? .on : .off

        if isTestMode {
            showVideoPlayer()
        } else {
            // Clean up any stale PIDs before checking
            cleanupStaleProcesses()
            if activeProcesses.isEmpty && !isScreensaverActive {
                hideVideoPlayer()
            }
        }
    }

    private func cleanupStaleProcesses() {
        let runningPIDs = getRunningPIDs()
        activeProcesses = activeProcesses.filter { runningPIDs.contains($0) }
    }

    private func getRunningPIDs() -> Set<pid_t> {
        var pids = Set<pid_t>()
        let task = Process()
        task.launchPath = "/bin/ps"
        task.arguments = ["-axo", "pid="]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                for line in output.split(separator: "\n") {
                    if let pid = pid_t(line.trimmingCharacters(in: .whitespaces)) {
                        pids.insert(pid)
                    }
                }
            }
        } catch {}
        return pids
    }

    @objc private func previousVideo() {
        videoWindows.forEach { $0.skipToPrevious() }
    }

    @objc private func nextVideo() {
        videoWindows.forEach { $0.skipToNext() }
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            settingsWindow = SettingsWindow()
            settingsWindow?.onSettingsChanged = { [weak self] in
                // Reload media if settings changed
                self?.videoWindows.forEach { $0.reloadMedia() }
            }
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func openMediaFolder() {
        let path: String
        if let customPath = SettingsWindow.getMediaFolderPath() {
            path = customPath
        } else if let resourcePath = Bundle.main.resourcePath {
            path = resourcePath
        } else {
            return
        }
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.open(url)
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    private func handleCommandStarted(command: String, pid: pid_t) {
        guard isEnabled else { return }

        activeProcesses.insert(pid)
        showVideoPlayer()
    }

    private func handleCommandFinished(pid: pid_t) {
        activeProcesses.remove(pid)

        // Only hide if no more active processes and test mode is off and screensaver not active
        if activeProcesses.isEmpty && !isTestMode && !isScreensaverActive {
            hideVideoPlayer()
        }
    }

    private func showVideoPlayer() {
        let targetCount = SettingsWindow.getVideoCount()

        if videoWindows.isEmpty {
            // Create new windows
            for i in 0..<targetCount {
                let window = VideoPlayerWindow(randomStart: i > 0 || targetCount > 1)
                window.setBounceMode(isBounceMode)
                window.setLoopMode(isLoopMode)
                window.showAndPlay()
                videoWindows.append(window)
            }
        } else if !videoWindows.first!.isVisible {
            // Windows exist but hidden - recreate with current count
            videoWindows.removeAll()
            for i in 0..<targetCount {
                let window = VideoPlayerWindow(randomStart: i > 0 || targetCount > 1)
                window.setBounceMode(isBounceMode)
                window.setLoopMode(isLoopMode)
                window.showAndPlay()
                videoWindows.append(window)
            }
        } else {
            // Already visible - just ensure settings are current
            videoWindows.forEach {
                $0.setBounceMode(isBounceMode)
                $0.setLoopMode(isLoopMode)
                $0.orderFrontRegardless()
            }
        }
    }

    private func hideVideoPlayer() {
        videoWindows.forEach {
            $0.stopPlayback()
            $0.orderOut(nil)
        }
        videoWindows.removeAll()
    }

    private func createMediaControls() -> NSView {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 220, height: 24))

        let buttonSize: CGFloat = 24
        let spacing: CGFloat = 16
        let totalWidth = buttonSize * 2 + spacing
        let startX = (220 - totalWidth) / 2

        // Previous button
        let prevButton = NSButton(frame: NSRect(x: startX, y: 0, width: buttonSize, height: buttonSize))
        prevButton.bezelStyle = .inline
        prevButton.isBordered = false
        prevButton.image = NSImage(systemSymbolName: "backward.fill", accessibilityDescription: "Previous")
        prevButton.imageScaling = .scaleProportionallyUpOrDown
        prevButton.target = self
        prevButton.action = #selector(previousVideo)
        prevButton.contentTintColor = .labelColor

        // Next button
        let nextButton = NSButton(frame: NSRect(x: startX + buttonSize + spacing, y: 0, width: buttonSize, height: buttonSize))
        nextButton.bezelStyle = .inline
        nextButton.isBordered = false
        nextButton.image = NSImage(systemSymbolName: "forward.fill", accessibilityDescription: "Next")
        nextButton.imageScaling = .scaleProportionallyUpOrDown
        nextButton.target = self
        nextButton.action = #selector(nextVideo)
        nextButton.contentTintColor = .labelColor

        container.addSubview(prevButton)
        container.addSubview(nextButton)

        return container
    }
}
