import AppKit

class SettingsWindow: NSWindow, NSTextFieldDelegate {
    private var mediaFolderField: NSTextField!
    private var timeoutField: NSTextField!
    private var timeoutStepper: NSStepper!
    private var videoCountSlider: NSSlider!
    private var videoCountLabel: NSTextField!

    private let mediaFolderKey = "AttentionApp.MediaFolder"
    private let screensaverTimeoutKey = "AttentionApp.ScreensaverTimeout"
    private let videoCountKey = "AttentionApp.VideoCount"

    var onSettingsChanged: (() -> Void)?

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 360),
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

        // ===== Media Folder Section =====
        let mediaLabel = NSTextField(labelWithString: "Media Folder:")
        mediaLabel.frame = NSRect(x: 20, y: 315, width: 100, height: 20)
        mediaLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        contentView.addSubview(mediaLabel)

        mediaFolderField = NSTextField(frame: NSRect(x: 20, y: 275, width: 320, height: 24))
        mediaFolderField.isEditable = false
        mediaFolderField.placeholderString = "App Resources (default)"
        contentView.addSubview(mediaFolderField)

        let browseButton = NSButton(frame: NSRect(x: 350, y: 275, width: 80, height: 24))
        browseButton.title = "Browse..."
        browseButton.bezelStyle = .rounded
        browseButton.target = self
        browseButton.action = #selector(browseFolder)
        contentView.addSubview(browseButton)

        let mediaHelpText = NSTextField(labelWithString: "Choose a folder containing your videos and images.")
        mediaHelpText.frame = NSRect(x: 20, y: 248, width: 400, height: 16)
        mediaHelpText.font = NSFont.systemFont(ofSize: 11)
        mediaHelpText.textColor = .secondaryLabelColor
        contentView.addSubview(mediaHelpText)

        let resetButton = NSButton(frame: NSRect(x: 20, y: 210, width: 120, height: 32))
        resetButton.title = "Use Default"
        resetButton.bezelStyle = .rounded
        resetButton.target = self
        resetButton.action = #selector(resetToDefault)
        contentView.addSubview(resetButton)

        // ===== Divider 1 =====
        let divider1 = NSBox(frame: NSRect(x: 20, y: 190, width: 410, height: 1))
        divider1.boxType = .separator
        contentView.addSubview(divider1)

        // ===== Video Count Section =====
        let videoCountTitleLabel = NSTextField(labelWithString: "Video Count:")
        videoCountTitleLabel.frame = NSRect(x: 20, y: 155, width: 150, height: 20)
        videoCountTitleLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        contentView.addSubview(videoCountTitleLabel)

        videoCountSlider = NSSlider(frame: NSRect(x: 20, y: 125, width: 320, height: 24))
        videoCountSlider.minValue = 1
        videoCountSlider.maxValue = 4
        videoCountSlider.numberOfTickMarks = 4
        videoCountSlider.allowsTickMarkValuesOnly = true
        videoCountSlider.integerValue = 1
        videoCountSlider.target = self
        videoCountSlider.action = #selector(videoCountChanged)
        contentView.addSubview(videoCountSlider)

        videoCountLabel = NSTextField(labelWithString: "1")
        videoCountLabel.frame = NSRect(x: 350, y: 125, width: 80, height: 24)
        videoCountLabel.alignment = .left
        videoCountLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        contentView.addSubview(videoCountLabel)

        let videoCountHelpText = NSTextField(labelWithString: "Number of videos on screen (random positions & directions).")
        videoCountHelpText.frame = NSRect(x: 20, y: 100, width: 400, height: 16)
        videoCountHelpText.font = NSFont.systemFont(ofSize: 11)
        videoCountHelpText.textColor = .secondaryLabelColor
        contentView.addSubview(videoCountHelpText)

        // ===== Divider 2 =====
        let divider2 = NSBox(frame: NSRect(x: 20, y: 80, width: 410, height: 1))
        divider2.boxType = .separator
        contentView.addSubview(divider2)

        // ===== Screensaver Section =====
        let screensaverLabel = NSTextField(labelWithString: "Screensaver Timeout:")
        screensaverLabel.frame = NSRect(x: 20, y: 50, width: 150, height: 20)
        screensaverLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        contentView.addSubview(screensaverLabel)

        timeoutField = NSTextField(frame: NSRect(x: 175, y: 48, width: 60, height: 24))
        timeoutField.stringValue = "10"
        timeoutField.alignment = .right
        timeoutField.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        timeoutField.delegate = self
        contentView.addSubview(timeoutField)

        timeoutStepper = NSStepper(frame: NSRect(x: 240, y: 48, width: 19, height: 24))
        timeoutStepper.minValue = 1
        timeoutStepper.maxValue = 99999
        timeoutStepper.increment = 1
        timeoutStepper.integerValue = 10
        timeoutStepper.target = self
        timeoutStepper.action = #selector(timeoutStepperChanged)
        contentView.addSubview(timeoutStepper)

        let secondsLabel = NSTextField(labelWithString: "seconds")
        secondsLabel.frame = NSRect(x: 265, y: 50, width: 60, height: 20)
        secondsLabel.font = NSFont.systemFont(ofSize: 13)
        contentView.addSubview(secondsLabel)

        let screensaverHelpText = NSTextField(labelWithString: "Time of inactivity before screensaver starts (any number).")
        screensaverHelpText.frame = NSRect(x: 20, y: 20, width: 400, height: 16)
        screensaverHelpText.font = NSFont.systemFont(ofSize: 11)
        screensaverHelpText.textColor = .secondaryLabelColor
        contentView.addSubview(screensaverHelpText)
    }

    private func loadSettings() {
        if let savedPath = UserDefaults.standard.string(forKey: mediaFolderKey) {
            mediaFolderField.stringValue = savedPath
        }

        let timeout = UserDefaults.standard.integer(forKey: screensaverTimeoutKey)
        let timeoutValue = timeout > 0 ? timeout : 10
        timeoutField.integerValue = timeoutValue
        timeoutStepper.integerValue = timeoutValue

        let count = UserDefaults.standard.integer(forKey: videoCountKey)
        videoCountSlider.integerValue = count > 0 ? count : 1
        updateVideoCountLabel()
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

    @objc private func timeoutStepperChanged() {
        timeoutField.integerValue = timeoutStepper.integerValue
        saveTimeout()
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        guard let textField = obj.object as? NSTextField, textField == timeoutField else { return }
        var value = timeoutField.integerValue
        if value < 1 { value = 1 }
        timeoutField.integerValue = value
        timeoutStepper.integerValue = value
        saveTimeout()
    }

    private func saveTimeout() {
        UserDefaults.standard.set(timeoutField.integerValue, forKey: screensaverTimeoutKey)
    }

    @objc private func videoCountChanged() {
        updateVideoCountLabel()
        UserDefaults.standard.set(videoCountSlider.integerValue, forKey: videoCountKey)
    }

    private func updateVideoCountLabel() {
        videoCountLabel.stringValue = "\(videoCountSlider.integerValue)"
    }

    static func getMediaFolderPath() -> String? {
        return UserDefaults.standard.string(forKey: "AttentionApp.MediaFolder")
    }

    static func getScreensaverTimeout() -> Double {
        let timeout = UserDefaults.standard.integer(forKey: "AttentionApp.ScreensaverTimeout")
        return timeout > 0 ? Double(timeout) : 10.0
    }

    static func getVideoCount() -> Int {
        let count = UserDefaults.standard.integer(forKey: "AttentionApp.VideoCount")
        return count > 0 ? count : 1
    }
}
