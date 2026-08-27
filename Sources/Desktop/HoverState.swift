import AppKit
import SwiftUI

/// Tracks whether the pointer is resting over the middle of the screen, which
/// is what reveals the media controls.
///
/// The wallpaper window itself cannot detect this: it ignores mouse events so
/// that clicks fall through to the Finder desktop behind it. Polling
/// `NSEvent.mouseLocation` sidesteps that without needing a global event
/// monitor (and the accessibility permission prompt one would bring).
@MainActor
final class HoverState: ObservableObject {
    static let shared = HoverState()

    @Published private(set) var isActive = false

    private var timer: Timer?
    private var lastInside = Date.distantPast
    /// Keeps the panel up briefly after the pointer leaves, so it does not
    /// flicker out while the user is reaching for a button.
    private let lingerDuration: TimeInterval = 0.7

    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 0.09, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
    }

    /// The region that reveals the controls, in screen coordinates.
    ///
    /// Kept tight around the lyrics themselves -- a large zone means the
    /// controls are up almost permanently and the lyrics can never be read.
    static func hotZone(for screen: NSScreen) -> CGRect {
        let frame = screen.frame
        let width = frame.width * 0.30
        let height = frame.height * 0.30
        return CGRect(
            x: frame.midX - width / 2,
            y: frame.midY - height / 2,
            width: width,
            height: height
        )
    }

    private func poll() {
        let location = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(location) } ?? NSScreen.main
        guard let screen else { return }

        if Self.hotZone(for: screen).contains(location) {
            lastInside = Date()
        }
        let shouldBeActive = Date().timeIntervalSince(lastInside) < lingerDuration
        guard shouldBeActive != isActive else { return }
        withAnimation(.easeOut(duration: 0.3)) {
            isActive = shouldBeActive
        }
    }
}
