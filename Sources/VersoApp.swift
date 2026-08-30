import AppKit
import SwiftUI

@main
struct VersoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var nowPlaying = NowPlayingMonitor.shared

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(nowPlaying)
        } label: {
            Image(nsImage: Self.menuBarIcon)
        }
        .menuBarExtraStyle(.window)
    }

    /// The mark from the wordmark's "o", carrying shape in alpha only.
    ///
    /// The asset is named with a `Template` suffix, which is what makes AppKit
    /// treat it as a template image: the system supplies the colour, so one
    /// file reads correctly in light mode, in dark mode, and inverted while
    /// the menu is open. A coloured icon would have to fight all three.
    private static let menuBarIcon: NSImage = {
        let image = NSImage(named: "MenuBarIconTemplate") ?? NSImage()
        image.size = NSSize(width: 18, height: 18)
        image.isTemplate = true
        return image
    }()
}
