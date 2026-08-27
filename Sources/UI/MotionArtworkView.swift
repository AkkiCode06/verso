import AVKit
import SwiftUI

/// Plays Apple Music's animated album art as the backdrop, looping silently.
///
/// Shown only for albums that actually ship motion artwork; everything else
/// falls back to the generated colour field.
struct MotionArtworkView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> PlayerView {
        let view = PlayerView()
        view.play(url: url)
        return view
    }

    func updateNSView(_ view: PlayerView, context: Context) {
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
            layer.videoGravity = .resizeAspectFill
            layer.frame = bounds
            layer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]

            wantsLayer = true
            self.layer = CALayer()
            self.layer?.addSublayer(layer)

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
            playerLayer?.frame = bounds
        }
    }
}
