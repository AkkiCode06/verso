import AppKit
import SwiftUI

/// Preferences. Each pane gives its main idea the room -- the sample on the
/// typeface pane, the preview on the background pane -- instead of stacking
/// equal-weight cards down the middle.
struct SettingsWindowView: View {
    @ObservedObject private var licensing = LicenseManager.shared
    @State private var tab: Tab = .typeface

    enum Tab: String, CaseIterable, Identifiable {
        case typeface, composition, background, behaviour, licence
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
            case .behaviour: return "Behaviour"
            case .licence: return "Licence"
            }
        }

        var symbol: String {
            switch self {
            case .typeface: return "textformat"
            case .composition: return "square.stack.3d.up"
            case .background: return "sparkles"
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
            Text("WAVELENGTH")
                .font(AppFont.ui(13, .bold))
                .tracking(1.6)
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.top, 28)
                .padding(.bottom, 22)

            ForEach(Tab.visible) { sidebarItem($0) }

            Spacer()

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
        .background(Color(red: 0.07, green: 0.07, blue: 0.09))
    }

    private func sidebarItem(_ item: Tab) -> some View {
        let selected = tab == item
        return Button {
            withAnimation(.easeOut(duration: 0.14)) { tab = item }
        } label: {
            HStack(spacing: 10) {
                // A rule marks the active pane rather than a filled pill.
                Rectangle()
                    .fill(selected ? Color.white : .clear)
                    .frame(width: 2, height: 15)
                Image(systemName: item.symbol)
                    .font(AppFont.ui(12))
                    .frame(width: 15)
                Text(item.title)
                    .font(AppFont.ui(12.5, selected ? .semibold : .regular))
                Spacer(minLength: 0)
            }
            .foregroundStyle(selected ? .white : .white.opacity(0.5))
            .padding(.trailing, 18)
            .padding(.vertical, 8)
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
        case .behaviour: BehaviourPane()
        case .licence: LicensePane()
        }
    }
}

// MARK: - Window

/// Presents the settings in its own window. Accessory apps have no ordinary
/// window, so this is managed by hand.
@MainActor
final class SettingsWindowController {
    static let shared = SettingsWindowController()
    private var window: NSWindow?

    func present() {
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
        window.backgroundColor = .black
        // Created in code, so it would otherwise be released on close while
        // this controller still points at it -- an over-release crash.
        window.isReleasedWhenClosed = false
        window.center()
        window.contentView = NSHostingView(rootView: SettingsWindowView())
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
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
                .foregroundStyle(.white)
            Text(subtitle)
                .font(AppFont.ui(12.5))
                .foregroundStyle(.white.opacity(0.55))
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
