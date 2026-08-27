import AppKit
import SwiftUI

/// First run, staged like a title sequence rather than a form: the effect runs
/// edge to edge, the type is set in the app's own display face, and the
/// content sits low-left the way a lyric does on the wallpaper.
struct OnboardingView: View {
    @ObservedObject private var settings = Settings.shared
    @ObservedObject private var licensing = LicenseManager.shared
    @State private var page = 0
    /// Relative, not absolute -- see BackgroundPane for why absolute time
    /// freezes a Float32 shader uniform.
    @State private var started = Date()
    var onFinish: () -> Void

    private let pageCount = LicenseManager.paywallEnabled ? 4 : 3

    /// A different effect per page, so the walkthrough is also the showreel.
    private var previewStyle: ShaderStyle {
        switch page {
        case 0: return .nebula
        case 1: return .silk
        case 2: return .ripple
        default: return .orbs
        }
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            livePreview

            // Weighted to the bottom, where the copy sits.
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.15), location: 0),
                    .init(color: .black.opacity(0.55), location: 0.45),
                    .init(color: .black.opacity(0.92), location: 1),
                ],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Spacer()
                content
                    .padding(.horizontal, 52)
                controls
                    .padding(.horizontal, 52)
                    .padding(.top, 30)
                    .padding(.bottom, 38)
            }

            progressRail
        }
        .frame(width: 720, height: 520)
        .colorScheme(.dark)
    }

    private var livePreview: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSince(started)
            ShaderBackgroundView(
                style: previewStyle,
                time: t, flow: t,
                tintA: Color(hue: 0.72, saturation: 0.66, brightness: 0.88),
                tintB: Color(hue: 0.54, saturation: 0.70, brightness: 0.70)
            )
        }
        .ignoresSafeArea()
    }

    /// A hairline at the very top edge instead of dots in the footer.
    private var progressRail: some View {
        VStack {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle().fill(.white.opacity(0.12))
                    Rectangle()
                        .fill(.white)
                        .frame(width: geometry.size.width * CGFloat(page + 1) / CGFloat(pageCount))
                        .animation(.easeOut(duration: 0.35), value: page)
                }
            }
            .frame(height: 2)
            Spacer()
        }
    }

    // MARK: - Pages

    @ViewBuilder
    private var content: some View {
        switch page {
        case 0: welcome
        case 1: typefacePage
        case 2: backgroundPage
        default: proPage
        }
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Your desktop\nbecomes the song.")
                .font(display(46))
                .foregroundStyle(.white)
                .lineSpacing(-2)
                .fixedSize(horizontal: false, vertical: true)

            Text("Live lyrics in time with Apple Music, over colour pulled from the record.")
                .font(AppFont.ui(15))
                .foregroundStyle(.white.opacity(0.7))
                .frame(maxWidth: 430, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            Label("macOS will ask permission to read Music. Nothing leaves this Mac.",
                  systemImage: "lock.shield")
                .font(AppFont.ui(11.5))
                .foregroundStyle(.white.opacity(0.45))
        }
    }

    private var typefacePage: some View {
        VStack(alignment: .leading, spacing: 18) {
            heading("Pick a voice", "Left automatic, the face follows the genre.")

            // The sample is the point of the page, so it gets the space.
            Text("Pull me closer")
                .font(sampleFont)
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 7) {
                ForEach(Settings.FontChoice.allCases) { choice in
                    chip(shortTitle(choice), selected: settings.fontChoice == choice) {
                        settings.fontChoice = choice
                    }
                }
            }
        }
    }

    private var backgroundPage: some View {
        VStack(alignment: .leading, spacing: 18) {
            heading("Pick a look", "Line patterns are drawn on the CPU. GPU effects are shader pieces — like this one.")

            HStack(spacing: 7) {
                ForEach(Settings.BackgroundMode.allCases) { mode in
                    chip(mode.title, selected: settings.backgroundMode == mode) {
                        settings.backgroundMode = mode
                    }
                }
            }
        }
    }

    private var proPage: some View {
        VStack(alignment: .leading, spacing: 18) {
            if licensing.isPro {
                heading("You're all set", "Every effect and animated covers are unlocked.")
                Label("Licence active", systemImage: "checkmark.seal.fill")
                    .font(AppFont.ui(14, .medium))
                    .foregroundStyle(.green)
            } else {
                heading("Free forever. Pro goes further.",
                        "Synced lyrics, 18 patterns and three GPU effects cost nothing.")
                HStack(spacing: 26) {
                    proPoint("cube.transparent", "9 more\nGPU effects")
                    proPoint("play.rectangle.on.rectangle", "Apple Music\nanimated covers")
                    proPoint("infinity", "Lifetime key,\nno subscription")
                }
                Text("Add a key any time from Settings.")
                    .font(AppFont.ui(11.5))
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
    }

    // MARK: - Pieces

    private func heading(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .font(display(34))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            Text(subtitle)
                .font(AppFont.ui(13.5))
                .foregroundStyle(.white.opacity(0.66))
                .frame(maxWidth: 460, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func proPoint(_ symbol: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol)
                .font(AppFont.ui(19, .light))
                .foregroundStyle(.white)
            Text(text)
                .font(AppFont.ui(12))
                .foregroundStyle(.white.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: 128, alignment: .leading)
    }

    private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: selected ? .semibold : .regular))
                .padding(.horizontal, 13)
                .padding(.vertical, 7)
                .background(
                    Capsule().fill(selected ? .white : .white.opacity(0.12))
                )
                .foregroundStyle(selected ? .black : .white.opacity(0.8))
        }
        .buttonStyle(.plain)
    }

    private var controls: some View {
        HStack(spacing: 18) {
            if page > 0 {
                Button("Back") { withAnimation(.easeOut(duration: 0.2)) { page -= 1 } }
                    .buttonStyle(.plain)
                    .font(AppFont.ui(13))
                    .foregroundStyle(.white.opacity(0.6))
            }
            Spacer()
            Button {
                if page == pageCount - 1 {
                    settings.hasOnboarded = true
                    onFinish()
                } else {
                    withAnimation(.easeOut(duration: 0.2)) { page += 1 }
                }
            } label: {
                HStack(spacing: 7) {
                    Text(page == pageCount - 1 ? "Start" : "Continue")
                        .font(AppFont.ui(13, .semibold))
                    Image(systemName: "arrow.right").font(AppFont.ui(11, .semibold))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Capsule().fill(.white))
                .foregroundStyle(.black)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.defaultAction)
        }
    }

    // MARK: - Type

    /// Headlines use the app's own display face, not the system font.
    private func display(_ size: CGFloat) -> Font {
        AppFont.display(size)
    }

    private var sampleFont: Font {
        // Manrope and a chosen Google family both come from the same
        // downloaded-and-registered path.
        if settings.fontChoice == .manrope, let regular = AppFont.regular {
            return .custom(AppFont.bold ?? regular, fixedSize: 52)
        }
        if settings.fontChoice == .google, let regular = settings.googleRegular {
            return .custom(regular, fixedSize: 52)
        }
        let face: LyricFace
        switch settings.fontChoice {
        case .serif: face = .serif
        case .slab: face = .slab
        case .soft: face = .soft
        case .sans, .auto, .google, .manrope: face = .sans
        }
        return face.font(size: 52, hero: true)
    }

    private func shortTitle(_ choice: Settings.FontChoice) -> String {
        switch choice {
        case .manrope: return "Manrope"
        case .auto: return "Automatic"
        case .sans: return "Sans"
        case .serif: return "Serif"
        case .slab: return "Slab"
        case .soft: return "Soft"
        case .google: return "Google"
        }
    }
}

/// Presents the onboarding as a standalone window, since this is an accessory
/// app with no ordinary window of its own.
@MainActor
final class OnboardingWindowController {
    static let shared = OnboardingWindowController()
    private var window: NSWindow?

    func presentIfNeeded() {
        guard !Settings.shared.hasOnboarded else { return }
        present()
    }

    func present() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 520),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.backgroundColor = .black
        // Created in code, so it would otherwise be released on close while
        // this controller still holds it -- an over-release crash.
        window.isReleasedWhenClosed = false
        window.center()
        window.contentView = NSHostingView(rootView: OnboardingView { [weak self] in self?.close() })
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }

    private func close() {
        // Deferred: called from a button inside this window's own hosting
        // view, so tearing it down synchronously would free it mid-event.
        DispatchQueue.main.async { [weak self] in
            self?.window?.orderOut(nil)
            self?.window?.contentView = nil
            self?.window = nil
        }
    }
}
