import AppKit
import SwiftUI

/// Hosts NowPlayingView directly as the desktop background -- a borderless,
/// non-interactive window per screen, sitting just above the real desktop
/// picture and below the desktop icons. Unlike a pre-rendered video, this is
/// the live SwiftUI view itself, so the gradient animation and lyric sync
/// are the real thing, not a loop.
@MainActor
final class DesktopWallpaperController {
    static let shared = DesktopWallpaperController()

    private var windows: [NSWindow] = []
    /// Last palette sampled from artwork, shared with the lock screen
    /// renderer so both surfaces use the same colours.
    var currentPalette: [SIMD3<Double>] = ColorExtractor.fallbackHSBPalette

    func start() {
        rebuild()
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.rebuild()
        }
    }

    private func rebuild() {
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()

        for screen in NSScreen.screens {
            let window = NSWindow(
                contentRect: screen.frame, styleMask: .borderless,
                backing: .buffered, defer: false, screen: screen
            )
            window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1)
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]
            window.ignoresMouseEvents = true
            window.isOpaque = true
            window.hasShadow = false
            window.backgroundColor = .black
            window.canHide = false
            window.isReleasedWhenClosed = false

            let hosting = NSHostingView(
                rootView: NowPlayingView().environmentObject(NowPlayingMonitor.shared)
            )
            hosting.frame = NSRect(origin: .zero, size: screen.frame.size)
            window.contentView = hosting

            window.orderFront(nil)
            windows.append(window)
        }
    }
}
