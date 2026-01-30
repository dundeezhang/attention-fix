import AppKit

class SettingsWindow: NSWindow {
    private var mediaFolderField: NSTextField!
    private let mediaFolderKey = "AttentionApp.MediaFolder"
    var onSettingsChanged: (() -> Void)?

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 180),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        self.title = "AttentionApp Settings"
        self.isReleasedWhenClosed = false
        self.center()

        setupUI()
        loadSettings()
    }

    private func setupUI() {
        let contentView = NSView(frame: self.contentRect(forFrameRect: self.frame))
        self.contentView = contentView

        // Media Folder Label
        let label = NSTextField(labelWithString: "Media Folder:")
        label.frame = NSRect(x: 20, y: 135, width: 100, height: 20)
        label.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        contentView.addSubview(label)

        // Media Folder Text Field
        mediaFolderField = NSTextField(frame: NSRect(x: 20, y: 95, width: 320, height: 24))
        mediaFolderField.isEditable = false
        mediaFolderField.placeholderString = "App Resources (default)"
        contentView.addSubview(mediaFolderField)

        // Browse Button
        let browseButton = NSButton(frame: NSRect(x: 350, y: 95, width: 80, height: 24))
        browseButton.title = "Browse..."
        browseButton.bezelStyle = .rounded
        browseButton.target = self
        browseButton.action = #selector(browseFolder)
        contentView.addSubview(browseButton)

        // Help Text
        let helpText = NSTextField(labelWithString: "Choose a folder containing your videos and images.")
        helpText.frame = NSRect(x: 20, y: 68, width: 400, height: 16)
        helpText.font = NSFont.systemFont(ofSize: 11)
        helpText.textColor = .secondaryLabelColor
        contentView.addSubview(helpText)

        // Reset Button
        let resetButton = NSButton(frame: NSRect(x: 20, y: 20, width: 120, height: 32))
        resetButton.title = "Use Default"
        resetButton.bezelStyle = .rounded
        resetButton.target = self
        resetButton.action = #selector(resetToDefault)
        contentView.addSubview(resetButton)
    }

    private func loadSettings() {
        if let savedPath = UserDefaults.standard.string(forKey: mediaFolderKey) {
            mediaFolderField.stringValue = savedPath
        }
    }

    @objc private func browseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select"
        panel.message = "Choose a folder containing your media files"

        if panel.runModal() == .OK, let url = panel.url {
            mediaFolderField.stringValue = url.path
            UserDefaults.standard.set(url.path, forKey: mediaFolderKey)
            onSettingsChanged?()
        }
    }

    @objc private func resetToDefault() {
        mediaFolderField.stringValue = ""
        UserDefaults.standard.removeObject(forKey: mediaFolderKey)
        onSettingsChanged?()
    }

    static func getMediaFolderPath() -> String? {
        return UserDefaults.standard.string(forKey: "AttentionApp.MediaFolder")
    }
}
