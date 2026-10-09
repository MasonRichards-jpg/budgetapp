import SwiftUI

enum AppTheme: String, Codable, CaseIterable, Identifiable {
    case mint, ocean, sunset, grape, rose, graphite
    var id: String { rawValue }

    var label: String { rawValue.capitalized }

    var colors: [Color] {
        switch self {
        case .mint: [.green, .mint]
        case .ocean: [.blue, .cyan]
        case .sunset: [.orange, .pink]
        case .grape: [.purple, .indigo]
        case .rose: [.pink, .red.opacity(0.7)]
        case .graphite: [Color(white: 0.35), Color(white: 0.55)]
        }
    }

    var accent: Color { colors[0] }

    /// Over-budget always reads as red, whatever the theme.
    func gradient(overBudget: Bool = false) -> LinearGradient {
        LinearGradient(colors: overBudget ? [.red, .orange] : colors,
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    func glow(overBudget: Bool = false) -> Color { (overBudget ? Color.red : accent).opacity(0.4) }
}

enum Appearance: String, Codable, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
    var scheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
