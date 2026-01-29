import Foundation

class ProcessMonitor {
    private var timer: Timer?
    private var knownProcesses: Set<pid_t> = []
    private var trackedProcesses: Set<pid_t> = []
    private let onCommandDetected: (String, pid_t) -> Void
    private let onCommandFinished: (pid_t) -> Void

    // Commands that trigger the video
    private let triggerCommands: Set<String> = [
        "install", "i", "add",
        "update", "upgrade", "up",
        "remove", "uninstall", "rm", "un",
        "build", "compile",
        "lint", "eslint", "prettier",
        "test", "jest", "vitest", "mocha",
        "clean", "clear", "cache",
        "audit", "outdated",
        "publish", "pack",
        "init", "create",
        "ci", "dedupe", "prune",
        "rebuild", "prepare",
        "link", "unlink",
        "exec", "dlx", "npx"
    ]

    // Commands that should NOT trigger the video
    private let excludeCommands: Set<String> = [
        "start", "dev", "serve", "watch",
        "run", "preview", "storybook"
    ]

    // Package managers to monitor
    private let packageManagers: Set<String> = [
        "npm", "pnpm", "yarn", "bun"
    ]

    init(onCommandDetected: @escaping (String, pid_t) -> Void, onCommandFinished: @escaping (pid_t) -> Void) {
        self.onCommandDetected = onCommandDetected
        self.onCommandFinished = onCommandFinished
    }

    func startMonitoring() {
        // Initial scan
        knownProcesses = getCurrentProcessPIDs()

        // Poll every 0.5 seconds
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkProcesses()
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        trackedProcesses.removeAll()
    }

    private func checkProcesses() {
        let currentPIDs = getCurrentProcessPIDs()

        // Check for new processes
        let newPIDs = currentPIDs.subtracting(knownProcesses)
        for pid in newPIDs {
            if let commandLine = getCommandLine(for: pid) {
                if shouldTrigger(commandLine: commandLine) {
                    trackedProcesses.insert(pid)
                    onCommandDetected(commandLine, pid)
                }
            }
        }

        // Check for finished tracked processes
        let finishedPIDs = trackedProcesses.subtracting(currentPIDs)
        for pid in finishedPIDs {
            trackedProcesses.remove(pid)
            onCommandFinished(pid)
        }

        knownProcesses = currentPIDs
    }

    private func getCurrentProcessPIDs() -> Set<pid_t> {
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
                let lines = output.split(separator: "\n")
                for line in lines {
                    if let pid = pid_t(line.trimmingCharacters(in: .whitespaces)) {
                        pids.insert(pid)
                    }
                }
            }
        } catch {
            // Ignore errors
        }

        return pids
    }

    private func getCommandLine(for pid: pid_t) -> String? {
        let task = Process()
        task.launchPath = "/bin/ps"
        task.arguments = ["-p", "\(pid)", "-o", "command="]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !output.isEmpty {
                return output
            }
        } catch {
            // Ignore errors
        }

        return nil
    }

    private func shouldTrigger(commandLine: String) -> Bool {
        let lowercased = commandLine.lowercased()
        let components = lowercased.split(separator: " ").map(String.init)

        // Check if it's a package manager command
        var isPackageManager = false
        var commandIndex = -1

        for (index, component) in components.enumerated() {
            let baseName = (component as NSString).lastPathComponent
            if packageManagers.contains(baseName) || packageManagers.contains(where: { component.hasSuffix("/\($0)") }) {
                isPackageManager = true
                commandIndex = index
                break
            }
        }

        guard isPackageManager, commandIndex < components.count - 1 else {
            return false
        }

        // Get the subcommand (e.g., "install", "build", etc.)
        let subcommand = components[commandIndex + 1]

        // Check if it's an excluded command first
        if excludeCommands.contains(subcommand) {
            return false
        }

        // Check if it's a run command with an excluded script
        if subcommand == "run" && commandIndex + 2 < components.count {
            let scriptName = components[commandIndex + 2]
            if excludeCommands.contains(scriptName) {
                return false
            }
            // If it's a run command with a trigger script, trigger it
            if triggerCommands.contains(scriptName) {
                return true
            }
        }

        // Check if it's a trigger command
        if triggerCommands.contains(subcommand) {
            return true
        }

        return false
    }
}
