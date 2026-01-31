import AppKit
import AVKit
import MediaPlayer

class VideoPlayerWindow: NSPanel {
    private var player: AVPlayer?
    private var playerView: AVPlayerView?
    private var imageView: NSImageView?
    private var loopObserver: Any?
    private var imageTimer: Timer?
    private var containerView: NSView?

    // Media playlist (videos and images)
    private var availableMedia: [URL] = []
    private var currentMediaURL: URL?
    private var mediaHistory: [URL] = []
    private var historyIndex: Int = -1
    private var isLoopMode = false

    // Supported file extensions
    private let videoExtensions = ["mp4", "mov", "m4v", "avi", "mkv", "webm"]
    private let imageExtensions = ["png", "jpg", "jpeg", "heic", "heif", "gif", "webp", "bmp", "tiff", "tif"]

    // Image display duration in seconds
    private let imageDuration: TimeInterval = 8.0

    // DVD bounce mode
    private var isBounceMode = false
    private var bounceTimer: Timer?
    private var velocityX: CGFloat = 4.5
    private var velocityY: CGFloat = 3.0
    private let bounceSpeed: CGFloat = 4.5

    // Random start option
    private var randomStart: Bool = false

    convenience init() {
        self.init(randomStart: false)
    }

    init(randomStart: Bool) {
        self.randomStart = randomStart

        // Start with a default size, will resize when media loads
        let screenRect = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 800, height: 600)

        let windowRect: NSRect
        if randomStart {
            // Random position within screen bounds
            let maxX = screenRect.maxX - 400
            let maxY = screenRect.maxY - 300
            let randomX = CGFloat.random(in: screenRect.minX...max(screenRect.minX, maxX))
            let randomY = CGFloat.random(in: screenRect.minY...max(screenRect.minY, maxY))
            windowRect = NSRect(x: randomX, y: randomY, width: 400, height: 300)
        } else {
            windowRect = NSRect(
                x: screenRect.midX - 200,
                y: screenRect.midY - 150,
                width: 400,
                height: 300
            )
        }

        // Random velocity direction
        if randomStart {
            velocityX = CGFloat.random(in: 3.0...6.0) * (Bool.random() ? 1 : -1)
            velocityY = CGFloat.random(in: 2.0...5.0) * (Bool.random() ? 1 : -1)
        }

        super.init(
            contentRect: windowRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView, .nonactivatingPanel, .utilityWindow],
            backing: .buffered,
            defer: false
        )

        // Make window float above everything - panels are typically ignored by tiling WMs
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .transient]
        self.hidesOnDeactivate = false
        self.isFloatingPanel = true
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.isMovableByWindowBackground = true

        // Transparent titlebar with content extending underneath
        self.titlebarAppearsTransparent = true
        self.titleVisibility = .hidden
        self.title = ""

        setupContainerView()
    }

    private func setupContainerView() {
        // Create container view
        containerView = NSView(frame: self.contentView!.bounds)
        containerView!.wantsLayer = true
        containerView!.layer?.backgroundColor = NSColor.black.cgColor
        containerView!.autoresizingMask = [.width, .height]

        // Setup AVPlayerView (hidden by default)
        playerView = AVPlayerView(frame: containerView!.bounds)
        playerView?.controlsStyle = .none
        playerView?.autoresizingMask = [.width, .height]
        playerView?.videoGravity = .resizeAspect
        playerView?.isHidden = true

        // Setup NSImageView (hidden by default)
        imageView = NSImageView(frame: containerView!.bounds)
        imageView?.imageScaling = .scaleProportionallyUpOrDown
        imageView?.autoresizingMask = [.width, .height]
        imageView?.isHidden = true

        containerView!.addSubview(playerView!)
        containerView!.addSubview(imageView!)
        self.contentView?.addSubview(containerView!)
    }

    private func isVideoFile(_ url: URL) -> Bool {
        return videoExtensions.contains(url.pathExtension.lowercased())
    }

    private func isImageFile(_ url: URL) -> Bool {
        return imageExtensions.contains(url.pathExtension.lowercased())
    }

    func showAndPlay() {
        // Load all available media
        availableMedia = getAllMediaURLs()

        // Reset history when starting fresh
        mediaHistory.removeAll()
        historyIndex = -1

        guard let url = getNextMediaURL() else {
            print("Warning: No media file found. Place videos or images in ~/Movies/ or the app bundle.")
            showPlaceholder()
            return
        }

        playMedia(url: url, addToHistory: true)
    }

    private func playMedia(url: URL, addToHistory: Bool = true) {
        // Stop any current playback
        stopCurrentMedia()

        currentMediaURL = url

        if addToHistory {
            // Remove any forward history when playing new media
            if historyIndex < mediaHistory.count - 1 {
                mediaHistory.removeLast(mediaHistory.count - historyIndex - 1)
            }
            mediaHistory.append(url)
            historyIndex = mediaHistory.count - 1
        }

        if isVideoFile(url) {
            playVideo(url: url)
        } else if isImageFile(url) {
            showImage(url: url)
        }
    }

    private func playVideo(url: URL) {
        // Hide image view, show player view
        imageView?.isHidden = true
        playerView?.isHidden = false

        // Load asset to get video size
        let asset = AVURLAsset(url: url)
        Task {
            await loadAndPlayVideo(asset: asset, url: url)
        }
    }

    private func showImage(url: URL) {
        // Hide player view, show image view
        playerView?.isHidden = true
        imageView?.isHidden = false

        guard let image = NSImage(contentsOf: url) else {
            playNextMedia()
            return
        }

        let imageWidth = image.size.width
        let imageHeight = image.size.height

        resizeWindow(contentWidth: imageWidth, contentHeight: imageHeight)

        imageView?.image = image
        imageView?.frame = containerView!.bounds

        // Show window
        self.orderFrontRegardless()

        // Start bouncing if enabled
        if isBounceMode {
            startBouncing()
        }

        // Set up timer for next media (unless loop mode)
        if !isLoopMode {
            imageTimer = Timer.scheduledTimer(withTimeInterval: imageDuration, repeats: false) { [weak self] _ in
                self?.playNextMedia()
            }
        }
    }

    private func stopCurrentMedia() {
        // Stop video
        player?.pause()
        player = nil
        playerView?.player = nil

        if let observer = loopObserver {
            NotificationCenter.default.removeObserver(observer)
            loopObserver = nil
        }

        // Stop image timer
        imageTimer?.invalidate()
        imageTimer = nil
    }

    private func getNextMediaURL() -> URL? {
        guard !availableMedia.isEmpty else { return nil }

        // If only one media file, return it
        if availableMedia.count == 1 {
            return availableMedia.first
        }

        // Pick a random media file excluding the current one
        let candidates = availableMedia.filter { $0 != currentMediaURL }
        return candidates.randomElement() ?? availableMedia.randomElement()
    }

    // MARK: - Skip Controls

    func skipToNext() {
        guard !availableMedia.isEmpty else { return }
        stopCurrentMedia()
        guard let nextURL = getNextMediaURL() else { return }
        playMedia(url: nextURL, addToHistory: true)
    }

    func skipToPrevious() {
        guard !mediaHistory.isEmpty, historyIndex > 0 else { return }
        stopCurrentMedia()
        historyIndex -= 1
        let previousURL = mediaHistory[historyIndex]
        playMedia(url: previousURL, addToHistory: false)
    }

    private func loadAndPlayVideo(asset: AVAsset, url: URL) async {
        do {
            let tracks = try await asset.loadTracks(withMediaType: .video)
            if let videoTrack = tracks.first {
                let size = try await videoTrack.load(.naturalSize)
                let transform = try await videoTrack.load(.preferredTransform)

                // Apply transform to get correct orientation
                let transformedSize = size.applying(transform)
                let videoWidth = abs(transformedSize.width)
                let videoHeight = abs(transformedSize.height)

                await MainActor.run {
                    resizeAndShowVideo(videoWidth: videoWidth, videoHeight: videoHeight, url: url)
                }
            } else {
                await MainActor.run {
                    resizeAndShowVideo(videoWidth: 400, videoHeight: 300, url: url)
                }
            }
        } catch {
            await MainActor.run {
                resizeAndShowVideo(videoWidth: 400, videoHeight: 300, url: url)
            }
        }
    }

    private func resizeWindow(contentWidth: CGFloat, contentHeight: CGFloat) {
        let screenRect = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 800, height: 600)

        // Minimum window size
        let minWidth: CGFloat = 320
        let minHeight: CGFloat = 240

        // Scale down to 60% of native size
        let sizeScale: CGFloat = 0.6

        var finalWidth = contentWidth * sizeScale
        var finalHeight = contentHeight * sizeScale

        // Enforce minimum size while maintaining aspect ratio
        if finalWidth < minWidth || finalHeight < minHeight {
            let widthRatio = minWidth / finalWidth
            let heightRatio = minHeight / finalHeight
            let scale = max(widthRatio, heightRatio)
            finalWidth *= scale
            finalHeight *= scale
        }

        // Cap at max size (smaller window)
        let maxWidth: CGFloat = 480
        let maxHeight: CGFloat = 360

        if finalWidth > maxWidth || finalHeight > maxHeight {
            let widthRatio = maxWidth / finalWidth
            let heightRatio = maxHeight / finalHeight
            let scale = min(widthRatio, heightRatio)
            finalWidth *= scale
            finalHeight *= scale
        }

        // Position in center of screen
        let windowRect = NSRect(
            x: screenRect.midX - finalWidth / 2,
            y: screenRect.midY - finalHeight / 2,
            width: finalWidth,
            height: finalHeight
        )

        self.setFrame(windowRect, display: true)

        // Update subviews
        containerView?.frame = self.contentView!.bounds
        playerView?.frame = containerView!.bounds
        imageView?.frame = containerView!.bounds
    }

    private func resizeAndShowVideo(videoWidth: CGFloat, videoHeight: CGFloat, url: URL) {
        resizeWindow(contentWidth: videoWidth, contentHeight: videoHeight)

        // Create player
        player = AVPlayer(url: url)
        player?.isMuted = true
        player?.allowsExternalPlayback = false
        playerView?.player = player

        // Prevent appearing in macOS media controls
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil

        // Seek to random start position (10-20 seconds)
        let randomStart = Double.random(in: 10...20)
        let startTime = CMTime(seconds: randomStart, preferredTimescale: 600)
        player?.seek(to: startTime)

        // Play next media when current one ends
        loopObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player?.currentItem,
            queue: .main
        ) { [weak self] _ in
            self?.playNextMedia()
        }

        // Show window and play
        self.orderFrontRegardless()
        player?.play()

        // Start bouncing if enabled
        if isBounceMode {
            startBouncing()
        }
    }

    private func playNextMedia() {
        // If loop mode is enabled, restart current media
        if isLoopMode {
            if let currentURL = currentMediaURL {
                if isVideoFile(currentURL) {
                    player?.seek(to: .zero)
                    player?.play()
                } else if isImageFile(currentURL) {
                    // Restart image timer
                    imageTimer?.invalidate()
                    imageTimer = Timer.scheduledTimer(withTimeInterval: imageDuration, repeats: false) { [weak self] _ in
                        self?.playNextMedia()
                    }
                }
            }
            return
        }

        stopCurrentMedia()

        // Get next media
        guard let nextURL = getNextMediaURL() else {
            // No other media, loop current one
            if let currentURL = currentMediaURL {
                playMedia(url: currentURL, addToHistory: false)
            }
            return
        }

        playMedia(url: nextURL, addToHistory: true)
    }

    func setLoopMode(_ enabled: Bool) {
        isLoopMode = enabled
    }

    func reloadMedia() {
        availableMedia = getAllMediaURLs()
    }

    private func getAllMediaURLs() -> [URL] {
        let allExtensions = videoExtensions + imageExtensions
        var mediaURLs: [URL] = []

        // Check custom media folder first (from settings)
        if let customPath = UserDefaults.standard.string(forKey: "AttentionApp.MediaFolder") {
            let customURL = URL(fileURLWithPath: customPath)
            if let contents = try? FileManager.default.contentsOfDirectory(at: customURL, includingPropertiesForKeys: nil) {
                for url in contents {
                    if allExtensions.contains(url.pathExtension.lowercased()) {
                        mediaURLs.append(url)
                    }
                }
            }
            if !mediaURLs.isEmpty {
                return mediaURLs
            }
        }

        // Check bundle for all media files
        if let resourcePath = Bundle.main.resourcePath {
            let resourceURL = URL(fileURLWithPath: resourcePath)
            if let contents = try? FileManager.default.contentsOfDirectory(at: resourceURL, includingPropertiesForKeys: nil) {
                for url in contents {
                    if allExtensions.contains(url.pathExtension.lowercased()) {
                        mediaURLs.append(url)
                    }
                }
            }
        }

        // If found media in bundle, return those
        if !mediaURLs.isEmpty {
            return mediaURLs
        }

        // Fallback: check common locations
        let paths = [
            NSHomeDirectory() + "/Movies/",
            NSHomeDirectory() + "/Desktop/",
            NSHomeDirectory() + "/Downloads/"
        ]

        for basePath in paths {
            if let contents = try? FileManager.default.contentsOfDirectory(atPath: basePath) {
                for file in contents {
                    let ext = (file as NSString).pathExtension.lowercased()
                    if allExtensions.contains(ext) {
                        mediaURLs.append(URL(fileURLWithPath: basePath + file))
                    }
                }
            }
        }

        return mediaURLs
    }

    private func showPlaceholder() {
        // Show a placeholder message if no media is found
        let label = NSTextField(labelWithString: "No media found.\nPlace videos or images in ~/Movies/")
        label.alignment = .center
        label.textColor = .white
        label.font = NSFont.systemFont(ofSize: 14)
        label.frame = self.contentView!.bounds
        label.autoresizingMask = [.width, .height]

        self.contentView?.addSubview(label)
        self.orderFrontRegardless()
    }

    func stopPlayback() {
        stopCurrentMedia()
        stopBouncing()
    }

    // MARK: - DVD Bounce Mode

    func setBounceMode(_ enabled: Bool) {
        isBounceMode = enabled
        if enabled && self.isVisible {
            startBouncing()
        } else {
            stopBouncing()
        }
    }

    private func startBouncing() {
        guard bounceTimer == nil else { return }

        // Randomize initial direction
        velocityX = Bool.random() ? bounceSpeed : -bounceSpeed
        velocityY = Bool.random() ? (bounceSpeed * 0.7) : -(bounceSpeed * 0.7)

        bounceTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
            self?.updateBouncePosition()
        }
    }

    private func stopBouncing() {
        bounceTimer?.invalidate()
        bounceTimer = nil
    }

    private func updateBouncePosition() {
        guard let screen = NSScreen.main?.visibleFrame else { return }

        var frame = self.frame

        // Move window
        frame.origin.x += velocityX
        frame.origin.y += velocityY

        // Bounce off left/right edges
        if frame.origin.x <= screen.origin.x {
            frame.origin.x = screen.origin.x
            velocityX = abs(velocityX)
        } else if frame.origin.x + frame.width >= screen.origin.x + screen.width {
            frame.origin.x = screen.origin.x + screen.width - frame.width
            velocityX = -abs(velocityX)
        }

        // Bounce off top/bottom edges
        if frame.origin.y <= screen.origin.y {
            frame.origin.y = screen.origin.y
            velocityY = abs(velocityY)
        } else if frame.origin.y + frame.height >= screen.origin.y + screen.height {
            frame.origin.y = screen.origin.y + screen.height - frame.height
            velocityY = -abs(velocityY)
        }

        self.setFrameOrigin(frame.origin)
    }

    deinit {
        stopPlayback()
    }
}
