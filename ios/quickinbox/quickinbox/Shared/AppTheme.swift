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
    let onInteractive: Color
    let sage: Color
    let sageStrong: Color
    let sageWash: Color

    func applying(_ tint: AppTint, for scheme: ColorScheme) -> AppThemePalette {
        AppThemePalette(
            grouped: grouped,
            paper: paper,
            raised: raised,
            primaryText: primaryText,
            secondaryText: secondaryText,
            separator: separator,
            fill: fill,
            signalInk: tint.color(for: scheme),
            interactiveTint: tint.color(for: scheme),
            onInteractive: tint.onColor(for: scheme),
            sage: sage,
            sageStrong: sageStrong,
            sageWash: sageWash
        )
    }
}

struct AppTint: Identifiable, Sendable {
    let id: String
    let title: String
    let light: Color
    let dark: Color

    func color(for scheme: ColorScheme) -> Color {
        scheme == .dark ? dark : light
    }

    func onColor(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.04, green: 0.05, blue: 0.06) : .white
    }
}

enum AppTintRegistry {
    static let defaultTintID = "indigo"

    static let all: [AppTint] = [
        AppTint(
            id: "indigo",
            title: "Indigo",
            light: Color(red: 0.25, green: 0.28, blue: 0.72),
            dark: Color(red: 0.68, green: 0.72, blue: 1.00)
        ),
        AppTint(
            id: "ocean",
            title: "Ocean",
            light: Color(red: 0.00, green: 0.38, blue: 0.62),
            dark: Color(red: 0.42, green: 0.78, blue: 1.00)
        ),
        AppTint(
            id: "sage",
            title: "Sage",
            light: Color(red: 0.12, green: 0.38, blue: 0.27),
            dark: Color(red: 0.50, green: 0.82, blue: 0.65)
        ),
        AppTint(
            id: "plum",
            title: "Plum",
            light: Color(red: 0.48, green: 0.20, blue: 0.52),
            dark: Color(red: 0.85, green: 0.60, blue: 0.90)
        ),
        AppTint(
            id: "ember",
            title: "Ember",
            light: Color(red: 0.66, green: 0.23, blue: 0.12),
            dark: Color(red: 1.00, green: 0.62, blue: 0.45)
        )
    ]

    static func tint(id: String) -> AppTint {
        all.first { $0.id == id } ?? all[0]
    }
}

struct AppTheme: Identifiable, Sendable {
    let id: String
    let title: String
    let detail: String
    let preferredColorScheme: ColorScheme?
    let lightPalette: AppThemePalette
    let darkPalette: AppThemePalette
    var tint: AppTint?

    func palette(for systemScheme: ColorScheme) -> AppThemePalette {
        let scheme = preferredColorScheme ?? systemScheme
        let palette = scheme == .dark ? darkPalette : lightPalette
        return tint.map { palette.applying($0, for: scheme) } ?? palette
    }

    func applying(_ tint: AppTint) -> AppTheme {
        var copy = self
        copy.tint = tint
        return copy
    }
}

enum AppThemeRegistry {
    static let defaultThemeID = "paper"

    static let all: [AppTheme] = [
        AppTheme(
            id: "paper",
            title: "Paper",
            detail: "Warm paper by day and charcoal at night",
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
            ),
            tint: nil
        ),
        AppTheme(
            id: "pureWhite",
            title: "Porcelain",
            detail: "A crisp, gallery-white canvas",
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
            ),
            tint: nil
        ),
        AppTheme(
            id: "amoledBlack",
            title: "Midnight",
            detail: "True black with luminous details",
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
            ),
            tint: nil
        ),
        AppTheme(
            id: "mist",
            title: "Silver Mist",
            detail: "Cool, quiet surfaces that follow the system",
            preferredColorScheme: nil,
            lightPalette: palette(
                grouped: Color(red: 0.935, green: 0.950, blue: 0.965),
                paper: Color(red: 0.975, green: 0.982, blue: 0.990),
                raised: .white,
                primary: Color(red: 0.075, green: 0.095, blue: 0.120),
                secondary: Color(red: 0.34, green: 0.39, blue: 0.44),
                separator: Color.black.opacity(0.12),
                fill: Color(red: 0.16, green: 0.25, blue: 0.34).opacity(0.07),
                isDark: false
            ),
            darkPalette: palette(
                grouped: Color(red: 0.055, green: 0.070, blue: 0.085),
                paper: Color(red: 0.075, green: 0.092, blue: 0.108),
                raised: Color(red: 0.105, green: 0.125, blue: 0.145),
                primary: Color(red: 0.925, green: 0.945, blue: 0.965),
                secondary: Color(red: 0.65, green: 0.70, blue: 0.75),
                separator: Color.white.opacity(0.16),
                fill: Color.white.opacity(0.08),
                isDark: true
            ),
            tint: nil
        ),
        AppTheme(
            id: "clay",
            title: "Soft Clay",
            detail: "Muted mineral warmth without losing contrast",
            preferredColorScheme: nil,
            lightPalette: palette(
                grouped: Color(red: 0.948, green: 0.925, blue: 0.905),
                paper: Color(red: 0.985, green: 0.968, blue: 0.950),
                raised: Color(red: 1.0, green: 0.987, blue: 0.973),
                primary: Color(red: 0.145, green: 0.115, blue: 0.105),
                secondary: Color(red: 0.40, green: 0.34, blue: 0.31),
                separator: Color.black.opacity(0.13),
                fill: Color(red: 0.40, green: 0.22, blue: 0.15).opacity(0.07),
                isDark: false
            ),
            darkPalette: palette(
                grouped: Color(red: 0.090, green: 0.072, blue: 0.066),
                paper: Color(red: 0.115, green: 0.092, blue: 0.083),
                raised: Color(red: 0.155, green: 0.125, blue: 0.112),
                primary: Color(red: 0.955, green: 0.925, blue: 0.900),
                secondary: Color(red: 0.72, green: 0.65, blue: 0.61),
                separator: Color.white.opacity(0.16),
                fill: Color.white.opacity(0.08),
                isDark: true
            ),
            tint: nil
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
            onInteractive: isDark
                ? Color(red: 0.055, green: 0.065, blue: 0.075)
                : .white,
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
    static let defaultValue = AppThemeRegistry
        .theme(
            id: UserDefaults.standard.string(forKey: AppPreferences.appThemeID)
                ?? AppThemeRegistry.defaultThemeID
        )
        .applying(
            AppTintRegistry.tint(id: AppTintRegistry.defaultTintID)
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
    case interactiveTint, onInteractive
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
        case .onInteractive: palette.onInteractive
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
