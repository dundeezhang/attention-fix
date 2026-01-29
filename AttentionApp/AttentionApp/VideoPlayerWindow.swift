import AppKit
import AVKit
import SwiftUI
import MediaPlayer

class VideoPlayerWindow: NSPanel {
    private var player: AVPlayer?
    private var playerView: AVPlayerView?
    private var loopObserver: Any?
    private var containerView: NSView?

    // Video playlist
    private var availableVideos: [URL] = []
    private var currentVideoURL: URL?

    // DVD bounce mode
    private var isBounceMode = false
    private var bounceTimer: Timer?
    private var velocityX: CGFloat = 4.5
    private var velocityY: CGFloat = 3.0
    private let bounceSpeed: CGFloat = 4.5

    init() {
        // Start with a default size, will resize when video loads
        let screenRect = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 800, height: 600)
        let windowRect = NSRect(
            x: screenRect.midX - 200,
            y: screenRect.midY - 150,
            width: 400,
            height: 300
        )

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

        setupVideoPlayer()
    }

    private func setupVideoPlayer() {
        // Create container view
        containerView = NSView(frame: self.contentView!.bounds)
        containerView!.wantsLayer = true
        containerView!.layer?.backgroundColor = NSColor.black.cgColor
        containerView!.autoresizingMask = [.width, .height]

        // Setup AVPlayerView
        playerView = AVPlayerView(frame: containerView!.bounds)
        playerView?.controlsStyle = .none
        playerView?.autoresizingMask = [.width, .height]
        playerView?.videoGravity = .resizeAspect

        containerView!.addSubview(playerView!)
        self.contentView?.addSubview(containerView!)
    }

    func showAndPlay() {
        // Load all available videos
        availableVideos = getAllVideoURLs()

        guard let url = getNextVideoURL() else {
            print("Warning: No video file found. Create test.mp4 in ~/Movies/ or the app bundle.")
            showPlaceholder()
            return
        }

        playVideo(url: url)
    }

    private func playVideo(url: URL) {
        currentVideoURL = url

        // Load asset to get video size
        let asset = AVURLAsset(url: url)
        Task {
            await loadAndPlay(asset: asset, url: url)
        }
    }

    private func getNextVideoURL() -> URL? {
        guard !availableVideos.isEmpty else { return nil }

        // If only one video, return it
        if availableVideos.count == 1 {
            return availableVideos.first
        }

        // Pick a random video excluding the current one
        let candidates = availableVideos.filter { $0 != currentVideoURL }
        return candidates.randomElement() ?? availableVideos.randomElement()
    }

    private func loadAndPlay(asset: AVAsset, url: URL) async {
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
                    resizeAndShow(videoWidth: videoWidth, videoHeight: videoHeight, url: url)
                }
            } else {
                await MainActor.run {
                    resizeAndShow(videoWidth: 400, videoHeight: 300, url: url)
                }
            }
        } catch {
            await MainActor.run {
                resizeAndShow(videoWidth: 400, videoHeight: 300, url: url)
            }
        }
    }

    private func resizeAndShow(videoWidth: CGFloat, videoHeight: CGFloat, url: URL) {
        let screenRect = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 800, height: 600)

        // Minimum window size
        let minWidth: CGFloat = 320
        let minHeight: CGFloat = 240

        // Scale down video to 60% of native size
        let sizeScale: CGFloat = 0.6

        var finalWidth = videoWidth * sizeScale
        var finalHeight = videoHeight * sizeScale

        // Enforce minimum size while maintaining aspect ratio
        if finalWidth < minWidth || finalHeight < minHeight {
            let widthRatio = minWidth / finalWidth
            let heightRatio = minHeight / finalHeight
            let scale = max(widthRatio, heightRatio)
            finalWidth *= scale
            finalHeight *= scale
        }

        // Cap at screen size with margin
        let maxWidth = screenRect.width - 40
        let maxHeight = screenRect.height - 40

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

        // Play next video when current one ends
        loopObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player?.currentItem,
            queue: .main
        ) { [weak self] _ in
            self?.playNextVideo()
        }

        // Show window and play
        self.orderFrontRegardless()
        player?.play()

        // Start bouncing if enabled
        if isBounceMode {
            startBouncing()
        }
    }

    private func playNextVideo() {
        // Remove observer for current video
        if let observer = loopObserver {
            NotificationCenter.default.removeObserver(observer)
            loopObserver = nil
        }

        // Get next video
        guard let nextURL = getNextVideoURL() else {
            // No other videos, loop current one
            player?.seek(to: .zero)
            player?.play()
            return
        }

        playVideo(url: nextURL)
    }

    private func getAllVideoURLs() -> [URL] {
        // Video file extensions to look for
        let videoExtensions = ["mp4", "mov", "m4v", "avi", "mkv"]

        var videoURLs: [URL] = []

        // Check bundle for all video files
        if let resourcePath = Bundle.main.resourcePath {
            let resourceURL = URL(fileURLWithPath: resourcePath)
            if let contents = try? FileManager.default.contentsOfDirectory(at: resourceURL, includingPropertiesForKeys: nil) {
                for url in contents {
                    if videoExtensions.contains(url.pathExtension.lowercased()) {
                        videoURLs.append(url)
                    }
                }
            }
        }

        // If found videos in bundle, return those
        if !videoURLs.isEmpty {
            return videoURLs
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
                    if videoExtensions.contains(ext) {
                        videoURLs.append(URL(fileURLWithPath: basePath + file))
                    }
                }
            }
        }

        return videoURLs
    }

    private func showPlaceholder() {
        // Show a placeholder message if no video is found
        let label = NSTextField(labelWithString: "No video file found.\nPlace test.mp4 in ~/Movies/")
        label.alignment = .center
        label.textColor = .white
        label.font = NSFont.systemFont(ofSize: 14)
        label.frame = self.contentView!.bounds
        label.autoresizingMask = [.width, .height]

        self.contentView?.addSubview(label)
        self.orderFrontRegardless()
    }

    func stopPlayback() {
        player?.pause()
        player = nil

        if let observer = loopObserver {
            NotificationCenter.default.removeObserver(observer)
            loopObserver = nil
        }

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
