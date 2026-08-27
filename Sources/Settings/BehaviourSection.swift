import SwiftUI

/// Shared section header styling, used by the menu bar.
@MainActor
func sectionTitle(_ text: String) -> some View {
    Text(text.uppercased())
        .font(AppFont.ui(9.5, .semibold))
        .foregroundStyle(.tertiary)
}
