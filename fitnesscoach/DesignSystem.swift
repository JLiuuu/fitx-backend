import SwiftUI

enum AppTheme {
    static let bgTop = Color.black
    static let bgMiddle = Color.black
    static let bgBottom = Color.black
    static let card = Color.clear
    static let cardBorder = Color.white.opacity(0.15)
    static let softStroke = Color(red: 0.41, green: 0.88, blue: 1.0).opacity(0.24)
    static let accent = Color(red: 0.655, green: 1.0, blue: 0.0) // #A7FF00
    static let accent2 = Color(red: 0.04, green: 0.52, blue: 1.0) // #0A84FF
    static let accent3 = Color(red: 0.20, green: 0.08, blue: 0.34)
    static let lightGreen = Color(red: 0.48, green: 1.0, blue: 0.60)
    static let lightBlue = Color(red: 0.30, green: 0.72, blue: 1.0)
    static let carbGreenHighlight = Color(red: 0.75, green: 1.0, blue: 0.28)
    static let warning = Color(red: 1.00, green: 0.62, blue: 0.33)
    static let textPrimary = Color.white.opacity(0.96)
    static let textSecondary = Color.white.opacity(0.68)
    static let textTertiary = Color.white.opacity(0.5)

    static let cardCornerRadius: CGFloat = 20
    static let controlCornerRadius: CGFloat = 12
    static let textFieldCornerRadius: CGFloat = 12
    static let primaryButtonHeight: CGFloat = 44
    static let dividerOpacity: Double = 0.08
    static let sectionSpacing: CGFloat = 14
    static let cardPadding: CGFloat = 14

    static let fastAnimation = Animation.spring(response: 0.28, dampingFraction: 0.82, blendDuration: 0.1)
    static let standardAnimation = Animation.spring(response: 0.42, dampingFraction: 0.86, blendDuration: 0.15)

    static var iconGradient: LinearGradient {
        LinearGradient(
            colors: [accent2, accent],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var progressGradientColors: [Color] {
        [accent2, accent]
    }

    static var nutritionCircleGradientColors: [Color] {
        [lightGreen, accent]
    }
}

struct AppBackground: ViewModifier {
    @State private var drifting = false

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    Color.black
                    Circle()
                        .fill(AppTheme.accent2)
                        .frame(width: 320, height: 320)
                        .blur(radius: 120)
                        .opacity(0.13)
                        .offset(
                            x: drifting ? -145 : -185,
                            y: drifting ? -235 : -285
                        )
                    Circle()
                        .fill(AppTheme.accent)
                        .frame(width: 320, height: 320)
                        .blur(radius: 120)
                        .opacity(0.12)
                        .offset(
                            x: drifting ? 205 : 245,
                            y: drifting ? 15 : 55
                        )
                    Circle()
                        .fill(AppTheme.accent3)
                        .frame(width: 300, height: 300)
                        .blur(radius: 120)
                        .opacity(0.11)
                        .offset(
                            x: drifting ? 10 : -20,
                            y: drifting ? 295 : 335
                        )
                }
                .ignoresSafeArea()
                .onAppear {
                    guard !drifting else { return }
                    withAnimation(.easeInOut(duration: 14).repeatForever(autoreverses: true)) {
                        drifting = true
                    }
                }
            )
    }
}

struct GlassCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(AppTheme.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                            .fill(AppTheme.card)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                    .stroke(AppTheme.cardBorder, lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.34), radius: 16, x: 0, y: 8)
            .shadow(color: AppTheme.accent2.opacity(0.12), radius: 13, x: 0, y: 5)
            .shadow(color: AppTheme.accent.opacity(0.09), radius: 12, x: 0, y: 5)
            .shadow(color: AppTheme.accent3.opacity(0.05), radius: 14, x: 0, y: 6)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous))
    }
}

extension View {
    func appBackground() -> some View {
        modifier(AppBackground())
    }

    func glassCard() -> some View {
        modifier(GlassCard())
    }
}
