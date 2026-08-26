import SwiftUI
import UIKit

/// A registry-driven theme system. To add a theme, define one `AppTheme` in
/// `all`; persistence, environment propagation, semantic colors, and the
/// Appearance selector will pick it up automatically.
struct AppThemePalette: Sendable {
    let grouped: Color
    let paper: Color
    let raised: Color
    let primaryText: Color
    let secondaryText: Color
    let separator: Color
    let fill: Color
    let signalInk: Color
    let interactiveTint: Color
    let sage: Color
    let sageStrong: Color
    let sageWash: Color
}

struct AppTheme: Identifiable, Sendable {
    let id: String
    let title: String
    let detail: String
    let preferredColorScheme: ColorScheme?
    let lightPalette: AppThemePalette
    let darkPalette: AppThemePalette

    func palette(for systemScheme: ColorScheme) -> AppThemePalette {
        let scheme = preferredColorScheme ?? systemScheme
        return scheme == .dark ? darkPalette : lightPalette
    }
}

enum AppThemeRegistry {
    static let defaultThemeID = "paper"

    static let all: [AppTheme] = [
        AppTheme(
            id: "paper",
            title: "Adaptive Paper",
            detail: "Warm paper by day and deep charcoal at night",
            preferredColorScheme: nil,
            lightPalette: palette(
                grouped: Color(red: 244/255, green: 241/255, blue: 233/255),
                paper: Color(red: 250/255, green: 248/255, blue: 242/255),
                raised: Color(red: 255/255, green: 253/255, blue: 248/255),
                primary: Color(red: 28/255, green: 29/255, blue: 27/255),
                secondary: Color(red: 91/255, green: 92/255, blue: 88/255),
                separator: Color.black.opacity(0.12),
                fill: Color.black.opacity(0.045),
                isDark: false
            ),
            darkPalette: palette(
                grouped: Color(red: 15/255, green: 19/255, blue: 21/255),
                paper: Color(red: 21/255, green: 25/255, blue: 27/255),
                raised: Color(red: 29/255, green: 34/255, blue: 37/255),
                primary: Color(red: 239/255, green: 237/255, blue: 231/255),
                secondary: Color(red: 177/255, green: 181/255, blue: 183/255),
                separator: Color.white.opacity(0.16),
                fill: Color.white.opacity(0.07),
                isDark: true
            )
        ),
        AppTheme(
            id: "pureWhite",
            title: "Pure White",
            detail: "Always use a crisp white canvas",
            preferredColorScheme: .light,
            lightPalette: palette(
                grouped: .white,
                paper: .white,
                raised: Color(red: 0.975, green: 0.975, blue: 0.980),
                primary: Color(red: 0.055, green: 0.065, blue: 0.075),
                secondary: Color(red: 0.34, green: 0.36, blue: 0.39),
                separator: Color.black.opacity(0.14),
                fill: Color.black.opacity(0.055),
                isDark: false
            ),
            darkPalette: palette(
                grouped: .white,
                paper: .white,
                raised: Color(red: 0.975, green: 0.975, blue: 0.980),
                primary: Color(red: 0.055, green: 0.065, blue: 0.075),
                secondary: Color(red: 0.34, green: 0.36, blue: 0.39),
                separator: Color.black.opacity(0.14),
                fill: Color.black.opacity(0.055),
                isDark: false
            )
        ),
        AppTheme(
            id: "amoledBlack",
            title: "AMOLED Black",
            detail: "Always use a true black canvas",
            preferredColorScheme: .dark,
            lightPalette: palette(
                grouped: .black,
                paper: .black,
                raised: Color(red: 0.055, green: 0.055, blue: 0.060),
                primary: Color(red: 0.96, green: 0.96, blue: 0.97),
                secondary: Color(red: 0.68, green: 0.70, blue: 0.73),
                separator: Color.white.opacity(0.18),
                fill: Color.white.opacity(0.10),
                isDark: true
            ),
            darkPalette: palette(
                grouped: .black,
                paper: .black,
                raised: Color(red: 0.055, green: 0.055, blue: 0.060),
                primary: Color(red: 0.96, green: 0.96, blue: 0.97),
                secondary: Color(red: 0.68, green: 0.70, blue: 0.73),
                separator: Color.white.opacity(0.18),
                fill: Color.white.opacity(0.10),
                isDark: true
            )
        )
    ]

    static func theme(id: String) -> AppTheme {
        all.first { $0.id == id } ?? all[0]
    }

    private static func palette(
        grouped: Color,
        paper: Color,
        raised: Color,
        primary: Color,
        secondary: Color,
        separator: Color,
        fill: Color,
        isDark: Bool
    ) -> AppThemePalette {
        AppThemePalette(
            grouped: grouped,
            paper: paper,
            raised: raised,
            primaryText: primary,
            secondaryText: secondary,
            separator: separator,
            fill: fill,
            signalInk: isDark
                ? Color(red: 0.620, green: 0.700, blue: 1.000)
                : Color(red: 0.080, green: 0.090, blue: 0.300),
            interactiveTint: isDark
                ? Color(red: 0.620, green: 0.700, blue: 1.000)
                : Color(red: 0.080, green: 0.090, blue: 0.300),
            sage: isDark
                ? Color(red: 0.490, green: 0.710, blue: 0.596)
                : Color(red: 0.204, green: 0.400, blue: 0.318),
            sageStrong: isDark
                ? Color(red: 0.600, green: 0.800, blue: 0.694)
                : Color(red: 0.133, green: 0.310, blue: 0.239),
            sageWash: isDark
                ? Color(red: 0.125, green: 0.212, blue: 0.169)
                : Color(red: 0.855, green: 0.910, blue: 0.875)
        )
    }

}

private struct AppThemeKey: EnvironmentKey {
    static let defaultValue = AppThemeRegistry.theme(
        id: UserDefaults.standard.string(forKey: AppPreferences.appThemeID)
            ?? AppThemeRegistry.defaultThemeID
    )
}

extension EnvironmentValues {
    var appTheme: AppTheme {
        get { self[AppThemeKey.self] }
        set { self[AppThemeKey.self] = newValue }
    }
}

enum AppThemeColorRole: Sendable {
    case grouped, paper, raised, primaryText, secondaryText, separator, fill
    case interactiveTint
    case signalInk, sage, sageStrong, sageWash
}

struct AppThemeColorStyle: ShapeStyle, View {
    let role: AppThemeColorRole

    init(_ role: AppThemeColorRole) {
        self.role = role
    }

    func resolve(in environment: EnvironmentValues) -> Color {
        let palette = environment.appTheme.palette(for: environment.colorScheme)
        return switch role {
        case .grouped: palette.grouped
        case .paper: palette.paper
        case .raised: palette.raised
        case .primaryText: palette.primaryText
        case .secondaryText: palette.secondaryText
        case .separator: palette.separator
        case .fill: palette.fill
        case .interactiveTint: palette.interactiveTint
        case .signalInk: palette.signalInk
        case .sage: palette.sage
        case .sageStrong: palette.sageStrong
        case .sageWash: palette.sageWash
        }
    }

    var body: some View {
        Rectangle().fill(self)
    }
}

@MainActor
enum SystemAppearance {
    static var colorScheme: ColorScheme {
        let interfaceStyle = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first(where: { $0.activationState != .unattached })?
            .screen.traitCollection.userInterfaceStyle
            ?? UITraitCollection.current.userInterfaceStyle
        return interfaceStyle == .dark ? .dark : .light
    }
}
