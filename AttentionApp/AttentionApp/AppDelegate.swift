import AppKit
import SwiftUI
import AVKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var processMonitor: ProcessMonitor!
    private var videoWindow: VideoPlayerWindow?
    private var isEnabled = true
    private var isBounceMode = false
    private var isLoopMode = false
    private var isTestMode = false
    private var activeProcesses: Set<pid_t> = []

    private let bounceModeKey = "AttentionApp.BounceMode"
    private let loopModeKey = "AttentionApp.LoopMode"

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Load saved preferences
        isBounceMode = UserDefaults.standard.bool(forKey: bounceModeKey)
        isLoopMode = UserDefaults.standard.bool(forKey: loopModeKey)

        setupStatusBar()
        setupProcessMonitor()
    }

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "eye.fill", accessibilityDescription: "Attention")
            button.image?.isTemplate = true
        }

        let menu = NSMenu()

        let enableItem = NSMenuItem(title: "Enabled", action: #selector(toggleEnabled), keyEquivalent: "e")
        enableItem.state = isEnabled ? .on : .off
        menu.addItem(enableItem)

        let bounceItem = NSMenuItem(title: "DVD Bounce Mode", action: #selector(toggleBounceMode), keyEquivalent: "b")
        bounceItem.state = isBounceMode ? .on : .off
        menu.addItem(bounceItem)

        let loopItem = NSMenuItem(title: "Loop Current Video", action: #selector(toggleLoopMode), keyEquivalent: "l")
        loopItem.state = isLoopMode ? .on : .off
        menu.addItem(loopItem)

        menu.addItem(NSMenuItem.separator())

        let testItem = NSMenuItem(title: "Test Video", action: #selector(toggleTestVideo), keyEquivalent: "t")
        testItem.state = isTestMode ? .on : .off
        menu.addItem(testItem)

        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "Previous Video", action: #selector(previousVideo), keyEquivalent: "["))
        menu.addItem(NSMenuItem(title: "Next Video", action: #selector(nextVideo), keyEquivalent: "]"))

        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))

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
        videoWindow?.setBounceMode(isBounceMode)

        // Save preference
        UserDefaults.standard.set(isBounceMode, forKey: bounceModeKey)
    }

    @objc private func toggleLoopMode(_ sender: NSMenuItem) {
        isLoopMode.toggle()
        sender.state = isLoopMode ? .on : .off
        videoWindow?.setLoopMode(isLoopMode)

        // Save preference
        UserDefaults.standard.set(isLoopMode, forKey: loopModeKey)
    }

    @objc private func toggleTestVideo(_ sender: NSMenuItem) {
        isTestMode.toggle()
        sender.state = isTestMode ? .on : .off

        if isTestMode {
            showVideoPlayer()
        } else {
            // Only hide if no active processes
            if activeProcesses.isEmpty {
                hideVideoPlayer()
            }
        }
    }

    @objc private func previousVideo() {
        videoWindow?.skipToPrevious()
    }

    @objc private func nextVideo() {
        videoWindow?.skipToNext()
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

        // Only hide if no more active processes and test mode is off
        if activeProcesses.isEmpty && !isTestMode {
            hideVideoPlayer()
        }
    }

    private func showVideoPlayer() {
        if videoWindow == nil {
            videoWindow = VideoPlayerWindow()
        }

        // Always apply current settings
        videoWindow?.setBounceMode(isBounceMode)
        videoWindow?.setLoopMode(isLoopMode)
        videoWindow?.showAndPlay()
    }

    private func hideVideoPlayer() {
        videoWindow?.stopPlayback()
        videoWindow?.orderOut(nil)
    }
}
