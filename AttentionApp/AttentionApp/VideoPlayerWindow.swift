import AppKit
import AVKit
import SwiftUI
import MediaPlayer

class VideoPlayerWindow: NSWindow {
    private var player: AVPlayer?
    private var playerView: AVPlayerView?
    private var loopObserver: Any?
    private var containerView: NSView?

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
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        // Make window float above everything
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
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
        // Get video file path - look in app bundle first, then in common locations
        let videoURL = getVideoURL()

        guard let url = videoURL else {
            print("Warning: No video file found. Create test.mp4 in ~/Movies/ or the app bundle.")
            showPlaceholder()
            return
        }

        // Load asset to get video size
        let asset = AVURLAsset(url: url)
        Task {
            await loadAndPlay(asset: asset, url: url)
        }
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

        // Scale down video to 60% of native size
        let sizeScale: CGFloat = 0.6

        var finalWidth = videoWidth * sizeScale
        var finalHeight = videoHeight * sizeScale

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

        // Loop video
        loopObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player?.currentItem,
            queue: .main
        ) { [weak self] _ in
            self?.player?.seek(to: .zero)
            self?.player?.play()
        }

        // Show window and play
        self.makeKeyAndOrderFront(nil)
        player?.play()
    }

    private func getVideoURL() -> URL? {
        // Video file extensions to look for
        let videoExtensions = ["mp4", "mov", "m4v", "avi", "mkv"]

        // Check bundle for all video files
        var videoURLs: [URL] = []

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

        // Return a random video if we found any
        if !videoURLs.isEmpty {
            return videoURLs.randomElement()
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

        return videoURLs.randomElement()
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
        self.makeKeyAndOrderFront(nil)
    }

    func stopPlayback() {
        player?.pause()
        player = nil

        if let observer = loopObserver {
            NotificationCenter.default.removeObserver(observer)
            loopObserver = nil
        }
    }

    deinit {
        stopPlayback()
    }
}
