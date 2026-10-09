import SwiftUI

/// Soft theme-coloured glow at the top of a screen. Shared so Today and Calendar feel like one app.
struct ThemeBackdrop: View {
    let theme: AppTheme

    var body: some View {
        ZStack(alignment: .top) {
            Color(.systemBackground)
            LinearGradient(colors: [theme.accent.opacity(0.2), .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: 420)
            RadialGradient(colors: [theme.accent.opacity(0.18), .clear], center: .top, startRadius: 0, endRadius: 380)
                .frame(height: 420)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }
}
