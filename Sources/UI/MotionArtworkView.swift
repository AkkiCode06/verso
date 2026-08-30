import AVKit
import SwiftUI

/// Plays Apple Music's animated album art as the backdrop, looping silently.
///
/// Shown only for albums that actually ship motion artwork; everything else
/// falls back to the generated colour field.
struct MotionArtworkView: NSViewRepresentable {
    let url: URL
    var placement: Settings.MotionPlacement = .fill

    func makeNSView(context: Context) -> PlayerView {
        let view = PlayerView()
        view.placement = placement
        view.play(url: url)
        return view
    }

    func updateNSView(_ view: PlayerView, context: Context) {
        view.placement = placement
        view.play(url: url)
    }

    static func dismantleNSView(_ view: PlayerView, coordinator: ()) {
        view.stop()
    }

    final class PlayerView: NSView {
        private var player: AVQueuePlayer?
        private var looper: AVPlayerLooper?
        private var playerLayer: AVPlayerLayer?
        private var currentURL: URL?
        /// The clip's real dimensions, once the asset reports them.
        ///
        /// Only a correction: motion covers are square by construction -- the
        /// provider asks for the square URL -- so layout assumes 1:1 until this
        /// arrives. The first version treated a nil here as "cannot lay out"
        /// and fell back to filling the bounds, which with `.resizeAspect`
        /// letterboxes; placement did nothing at all until the load returned,
        /// and nothing ever if it failed.
        private var naturalSize: CGSize?

        /// What layout works from. Square is the right guess for album art.
        private var videoSize: CGSize {
            guard let s = naturalSize, s.width > 0, s.height > 0 else {
                return CGSize(width: 1, height: 1)
            }
            return s
        }

        var placement: Settings.MotionPlacement = .fill {
            didSet { if placement != oldValue { needsLayout = true } }
        }

        func play(url: URL) {
            guard currentURL != url else { return }
            currentURL = url
            stop()

            let queuePlayer = AVQueuePlayer()
            queuePlayer.isMuted = true
            queuePlayer.preventsDisplaySleepDuringVideoPlayback = false

            let item = AVPlayerItem(url: url)
            // AVPlayerLooper gives a gapless repeat, which matters when the
            // clip is only a few seconds long.
            looper = AVPlayerLooper(player: queuePlayer, templateItem: item)

            let layer = AVPlayerLayer(player: queuePlayer)
            // The layer's own frame does the fitting, so gravity must not also
            // scale -- otherwise the two fight and the anchor is ignored.
            layer.videoGravity = .resizeAspect
            layer.frame = bounds

            naturalSize = nil
            Task { [weak self] in
                guard let track = try? await item.asset.loadTracks(withMediaType: .video).first,
                      let size = try? await track.load(.naturalSize)
                else { return }
                await MainActor.run {
                    self?.naturalSize = size
                    self?.needsLayout = true
                }
            }

            wantsLayer = true
            let host = CALayer()
            // A filled layer is deliberately larger than the view, so without
            // this the overhang draws outside its bounds and over whatever is
            // next to it.
            host.masksToBounds = true
            self.layer = host
            host.addSublayer(layer)

            playerLayer = layer
            player = queuePlayer
            queuePlayer.play()
        }

        func stop() {
            player?.pause()
            playerLayer?.removeFromSuperlayer()
            playerLayer = nil
            looper = nil
            player = nil
        }

        override func layout() {
            super.layout()
            guard let layer = playerLayer else { return }

            let video = videoSize
            guard bounds.width > 0, bounds.height > 0 else { return }

            let scale: CGFloat
            switch placement {
            case .fit:
                scale = min(bounds.width / video.width, bounds.height / video.height)
            case .fill, .fillTop, .fillBottom:
                scale = max(bounds.width / video.width, bounds.height / video.height)
            }

            let size = CGSize(width: video.width * scale, height: video.height * scale)
            let x = (bounds.width - size.width) / 2
            let y: CGFloat
            switch placement {
            // AppKit's origin is bottom-left, so "keep the top of the cover"
            // means pushing the overhang off the bottom of the view.
            case .fillTop: y = bounds.height - size.height
            case .fillBottom: y = 0
            case .fill, .fit: y = (bounds.height - size.height) / 2
            }
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            layer.frame = CGRect(x: x, y: y, width: size.width, height: size.height)
            CATransaction.commit()
        }
    }
}
