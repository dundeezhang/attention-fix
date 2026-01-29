import Foundation

class ProcessMonitor {
    private var timer: Timer?
    private var knownProcesses: Set<pid_t> = []
    private var trackedProcesses: Set<pid_t> = []
    private let onCommandDetected: (String, pid_t) -> Void
    private let onCommandFinished: (pid_t) -> Void

    // Subcommands that trigger the video (for package managers)
    private let triggerSubcommands: Set<String> = [
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

    // Subcommands that should NOT trigger the video
    private let excludeSubcommands: Set<String> = [
        "start", "dev", "serve", "watch",
        "run", "preview", "storybook",
        "list", "show", "info", "search",
        "config", "help", "version", "--version", "-v", "-h", "--help"
    ]

    // Package managers that need a subcommand check
    private let packageManagers: Set<String> = [
        "npm", "pnpm", "yarn", "bun",
        "pip", "pip3", "pipx", "uv",
        "poetry", "pdm", "conda", "mamba",
        "cargo", "rustup",
        "go",
        "gem", "bundle", "bundler",
        "composer",
        "mvn", "maven", "gradle", "gradlew",
        "dotnet", "nuget",
        "mix",  // Elixir
        "cabal", "stack",  // Haskell
        "nimble",  // Nim
        "pub",  // Dart
        "swift",
        "vcpkg", "conan",  // C++ package managers
        "brew", "brew.rb"  // Homebrew (brew.rb is the actual executable)
    ]

    // Compilers/build tools that always trigger (no subcommand needed)
    private let alwaysTriggerCommands: Set<String> = [
        "gcc", "g++", "clang", "clang++", "cc", "c++",
        "make", "gmake", "cmake", "ninja", "meson",
        "rustc", "javac", "kotlinc", "scalac",
        "tsc",  // TypeScript compiler
        "swiftc",
        "ghc",  // Haskell
        "ocamlc", "ocamlopt",
        "fpc",  // Pascal
        "gfortran", "ifort",
        "nasm", "yasm",  // Assembly
        "zig",
        "dmd", "ldc", "gdc"  // D language
    ]

    // Go subcommands that trigger
    private let goTriggerSubcommands: Set<String> = [
        "build", "install", "get", "mod", "test", "generate", "clean"
    ]

    // Cargo subcommands that trigger
    private let cargoTriggerSubcommands: Set<String> = [
        "build", "install", "test", "check", "clippy", "clean", "update", "fetch", "publish"
    ]

    // Swift subcommands that trigger
    private let swiftTriggerSubcommands: Set<String> = [
        "build", "test", "package", "run"
    ]

    // Homebrew subcommands that trigger
    private let brewTriggerSubcommands: Set<String> = [
        "install", "reinstall", "upgrade", "update",
        "uninstall", "remove", "cleanup", "autoremove",
        "link", "unlink", "postinstall",
        "fetch", "bundle"
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

        guard !components.isEmpty else { return false }

        // Find the actual command (skip env vars, paths, etc.)
        for (index, component) in components.enumerated() {
            let baseName = (component as NSString).lastPathComponent

            // Check if it's an always-trigger compiler/build tool
            if alwaysTriggerCommands.contains(baseName) {
                return true
            }

            // Check if it's a package manager
            if packageManagers.contains(baseName) {
                return checkPackageManagerSubcommand(baseName: baseName, components: components, commandIndex: index)
            }
        }

        // Fallback: check for brew in the command line (runs as ruby with brew.rb)
        if let brewIndex = components.firstIndex(where: {
            $0.hasSuffix("/brew") || $0.hasSuffix("/brew.rb") || $0 == "brew" || $0 == "brew.rb"
        }) {
            return checkPackageManagerSubcommand(baseName: "brew", components: components, commandIndex: brewIndex)
        }

        return false
    }

    private func checkPackageManagerSubcommand(baseName: String, components: [String], commandIndex: Int) -> Bool {
        guard commandIndex < components.count - 1 else { return false }

        let subcommand = components[commandIndex + 1]

        // Check if it's an excluded command first
        if excludeSubcommands.contains(subcommand) {
            return false
        }

        // Special handling for Go
        if baseName == "go" {
            return goTriggerSubcommands.contains(subcommand)
        }

        // Special handling for Cargo
        if baseName == "cargo" {
            return cargoTriggerSubcommands.contains(subcommand)
        }

        // Special handling for Swift
        if baseName == "swift" {
            return swiftTriggerSubcommands.contains(subcommand)
        }

        // Special handling for Homebrew
        if baseName == "brew" || baseName == "brew.rb" {
            return brewTriggerSubcommands.contains(subcommand)
        }

        // Check if it's a run command with an excluded script
        if subcommand == "run" && commandIndex + 2 < components.count {
            let scriptName = components[commandIndex + 2]
            if excludeSubcommands.contains(scriptName) {
                return false
            }
            if triggerSubcommands.contains(scriptName) {
                return true
            }
        }

        // Check if it's a trigger subcommand
        if triggerSubcommands.contains(subcommand) {
            return true
        }

        return false
    }
}
