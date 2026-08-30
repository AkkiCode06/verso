import AppKit
import SwiftUI

/// Preferences. Each pane gives its main idea the room -- the sample on the
/// typeface pane, the preview on the background pane -- instead of stacking
/// equal-weight cards down the middle.
struct SettingsWindowView: View {
    @ObservedObject private var licensing = LicenseManager.shared
    @State private var tab: Tab = .typeface

    enum Tab: String, CaseIterable, Identifiable {
        case typeface, composition, background, appleMusic, behaviour, licence
        var id: String { rawValue }

        /// The licence pane only exists while the paid tier does.
        static var visible: [Tab] {
            LicenseManager.paywallEnabled ? allCases : allCases.filter { $0 != .licence }
        }

        var title: String {
            switch self {
            case .typeface: return "Typeface"
            case .composition: return "Composition"
            case .background: return "Background"
            case .appleMusic: return "Apple Music"
            case .behaviour: return "Behaviour"
            case .licence: return "Licence"
            }
        }

        var symbol: String {
            switch self {
            case .typeface: return "textformat"
            case .composition: return "square.stack.3d.up"
            case .background: return "sparkles"
            case .appleMusic: return "music.note.tv"
            case .behaviour: return "slider.horizontal.3"
            case .licence: return "checkmark.seal"
            }
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            pane
        }
        .frame(width: 860, height: 580)
        .colorScheme(.dark)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            // The real wordmark, lifted off the icon's gradient, rather than
            // the name re-set in whatever typeface happens to be to hand --
            // that never quite matches the logo and looks like a near-miss.
            Wordmark(width: 84)
                .padding(.horizontal, 20)
                .padding(.top, 26)
                .padding(.bottom, 20)

            ForEach(Tab.visible) { sidebarItem($0) }

            Spacer()

            signature

            if LicenseManager.paywallEnabled {
                HStack(spacing: 6) {
                    Circle()
                        .fill(licensing.isPro ? Color.green : .white.opacity(0.3))
                        .frame(width: 5, height: 5)
                    Text(licensing.isPro ? "Pro" : "Free")
                        .font(AppFont.ui(11, .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 22)
            }
        }
        .frame(width: 186)
        .background(
            ZStack {
                Verso.surfaceRaised
                // A whisper of the icon's gradient, so the sidebar belongs to
                // the brand without competing with the pane beside it.
                LinearGradient(colors: [Verso.violet.opacity(0.16), .clear],
                               startPoint: .top, endPoint: .bottom)
            }
        )
        .overlay(alignment: .trailing) {
            Rectangle().fill(Verso.cream.opacity(0.07)).frame(width: 1)
        }
    }

    /// Sits at the foot of the sidebar, quiet enough to be found rather than
    /// noticed. The version comes from the bundle, so it cannot drift out of
    /// step with what was actually shipped.
    private var signature: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text("Built with")
                    .font(.system(size: 10.5, weight: .medium))
                Image(systemName: "heart.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(Verso.violet.opacity(0.9))
            }
            Text("Verso \(Self.version)")
                .font(.system(size: 9.5))
                .foregroundStyle(Verso.cream.opacity(0.20))
        }
        .foregroundStyle(Verso.cream.opacity(0.40))
        .padding(.horizontal, 22)
        .padding(.bottom, LicenseManager.paywallEnabled ? 12 : 20)
    }

    private static let version: String =
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"

    private func sidebarItem(_ item: Tab) -> some View {
        let selected = tab == item
        return Button {
            withAnimation(.easeOut(duration: 0.14)) { tab = item }
        } label: {
            HStack(spacing: 10) {
                // A rule marks the active pane rather than a filled pill.
                Capsule()
                    .fill(selected ? AnyShapeStyle(Verso.accentGradient)
                                   : AnyShapeStyle(Color.clear))
                    .frame(width: 2.5, height: 16)
                Image(systemName: item.symbol)
                    .font(AppFont.ui(12))
                    .frame(width: 15)
                Text(item.title)
                    .font(AppFont.ui(12.5, selected ? .semibold : .regular))
                Spacer(minLength: 0)
            }
            .foregroundStyle(selected ? Verso.cream : Verso.cream.opacity(0.48))
            .padding(.trailing, 18)
            .padding(.vertical, 8)
            .background(alignment: .leading) {
                if selected {
                    LinearGradient(colors: [Verso.violet.opacity(0.20), .clear],
                                   startPoint: .leading, endPoint: .trailing)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Panes

    @ViewBuilder
    private var pane: some View {
        switch tab {
        case .typeface: TypefacePane()
        case .composition: CompositionPane()
        case .background: BackgroundPane()
        case .appleMusic: AppleMusicPane()
        case .behaviour: BehaviourPane()
        case .licence: LicensePane()
        }
    }
}

// MARK: - Window

/// Presents the settings in its own window. Accessory apps have no ordinary
/// window, so this is managed by hand.
@MainActor
final class SettingsWindowController: NSObject {
    static let shared = SettingsWindowController()
    private var window: NSWindow?

    func present() {
        // Verso is an accessory app -- no Dock icon, since the wallpaper is
        // the interface. But an accessory app's window cannot become properly
        // key, so Settings would open without a working menu bar and could be
        // lost behind other windows with no way to bring it back. Becoming a
        // regular app for as long as Settings is open fixes both, and the Dock
        // icon gives somewhere to click back to.
        NSApp.setActivationPolicy(.regular)

        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 860, height: 580),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.backgroundColor = NSColor(Verso.surface)
        // Created in code, so it would otherwise be released on close while
        // this controller still points at it -- an over-release crash.
        window.isReleasedWhenClosed = false
        window.center()
        window.contentView = NSHostingView(rootView: SettingsWindowView())
        window.delegate = self
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }
}

extension SettingsWindowController: NSWindowDelegate {
    /// Back to an accessory app once Settings goes away, so the Dock icon and
    /// menu bar do not linger for an app with nothing left on screen.
    func windowWillClose(_ notification: Notification) {
        // Deferred: the policy change tears down the menu bar, and doing that
        // synchronously inside the window's own close notification is not safe.
        DispatchQueue.main.async {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}

/// Verso's wordmark, from the app icon with its background keyed out.
///
/// Loaded through `NSImage` rather than `Image("name")`: the latter resolves
/// against asset catalogs, and this ships as a loose bundle resource, so the
/// SwiftUI form silently renders nothing.
struct Wordmark: View {
    var width: CGFloat = 84

    var body: some View {
        if let image = NSImage(named: "Wordmark") {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: width)
                .accessibilityLabel("Verso")
        }
    }
}

// MARK: - Shared pane chrome

struct PaneHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(AppFont.display(30))
                .foregroundStyle(Verso.brandGradient)
            Text(subtitle)
                .font(AppFont.ui(12.5))
                .foregroundStyle(Verso.cream.opacity(0.52))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Pill selector used across the panes instead of stock menu pickers.
struct ChipRow<Item: Identifiable & Equatable>: View {
    let items: [Item]
    let title: (Item) -> String
    @Binding var selection: Item

    var body: some View {
        HStack(spacing: 6) {
            ForEach(items) { item in
                Button { selection = item } label: {
                    Text(title(item))
                        .font(AppFont.ui(11.5, selection == item ? .semibold : .regular))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(selection == item ? .white : .white.opacity(0.10)))
                        .foregroundStyle(selection == item ? .black : .white.opacity(0.78))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
