import AppKit
import Combine
import SwiftUI

/// Hosts the media controls in their own panel, floating just above the
/// desktop icons but below ordinary windows.
///
/// A separate window is needed because the wallpaper window deliberately
/// ignores mouse events (so clicks reach the Finder desktop). This panel
/// accepts them, but only while the controls are actually visible -- the
/// rest of the time it stays click-through so it never steals a click meant
/// for the desktop.
@MainActor
final class ControlPanelController {
    static let shared = ControlPanelController()

    private var panel: NSPanel?
    private var cancellable: AnyCancellable?

    func start() {
        guard panel == nil, let screen = NSScreen.main else { return }

        // Centred, so the controls occupy the same space the lyrics do and
        // read as a replacement for them rather than a separate bar.
        let size = CGSize(width: 400, height: 330)
        let frame = CGRect(
            x: screen.frame.midX - size.width / 2,
            y: screen.frame.midY - size.height / 2,
            width: size.width,
            height: size.height
        )

        let panel = NSPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isMovable = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]
        // Without an explicit frame the hosting view shrinks to fit its
        // content and sits at the window's left edge, which shifts everything
        // visibly off-centre.
        let hosting = NSHostingView(
            rootView: MediaControlsView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .environmentObject(NowPlayingMonitor.shared)
        )
        hosting.frame = CGRect(origin: .zero, size: frame.size)
        hosting.autoresizingMask = [.width, .height]
        panel.contentView = hosting
        panel.orderFront(nil)
        self.panel = panel

        cancellable = HoverState.shared.$isActive.sink { [weak self] isActive in
            self?.panel?.ignoresMouseEvents = !isActive
        }
    }
}
