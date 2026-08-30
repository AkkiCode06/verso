import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppFont.preload()
        DesktopWallpaperController.shared.start()
        ControlPanelController.shared.start()
        HoverState.shared.start()
        OnboardingWindowController.shared.presentIfNeeded()
    }

    /// The wallpaper lives in borderless windows that AppKit does not count,
    /// so closing the onboarding window would otherwise look like the last
    /// window closing and terminate the app mid-song.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
