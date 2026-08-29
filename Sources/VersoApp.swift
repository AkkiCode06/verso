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
            Image(systemName: "waveform")
        }
        .menuBarExtraStyle(.window)
    }
}
