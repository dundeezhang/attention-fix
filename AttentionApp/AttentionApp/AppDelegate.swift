import AppKit
import SwiftUI
import AVKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var processMonitor: ProcessMonitor!
    private var videoWindow: VideoPlayerWindow?
    private var isEnabled = true
    private var activeProcesses: Set<pid_t> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
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

        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "Test Video", action: #selector(testVideo), keyEquivalent: "t"))

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

    @objc private func testVideo() {
        showVideoPlayer()

        // Auto-hide after 5 seconds for test
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            if self?.activeProcesses.isEmpty == true {
                self?.hideVideoPlayer()
            }
        }
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

        // Only hide if no more active processes
        if activeProcesses.isEmpty {
            hideVideoPlayer()
        }
    }

    private func showVideoPlayer() {
        if videoWindow == nil {
            videoWindow = VideoPlayerWindow()
        }

        videoWindow?.showAndPlay()
    }

    private func hideVideoPlayer() {
        videoWindow?.stopPlayback()
        videoWindow?.orderOut(nil)
    }
}
