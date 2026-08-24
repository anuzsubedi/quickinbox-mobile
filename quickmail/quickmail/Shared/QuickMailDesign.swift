import SwiftUI
import UIKit

enum AppCanvasStyle: String, CaseIterable, Identifiable, Sendable {
    case paper
    case pureWhite
    case amoledBlack

    var id: String { rawValue }
    var title: String {
        switch self {
        case .paper: "Adaptive Paper"
        case .pureWhite: "Pure White"
        case .amoledBlack: "AMOLED Black"
        }
    }
    var detail: String {
        switch self {
        case .paper: "Warm paper by day and deep charcoal at night"
        case .pureWhite: "Always use a crisp white canvas"
        case .amoledBlack: "Always use a true black canvas"
        }
    }
    var pickerTitle: String {
        switch self {
        case .paper: "Paper"
        case .pureWhite: "White"
        case .amoledBlack: "AMOLED"
        }
    }
    var preferredColorScheme: ColorScheme? {
        switch self {
        case .paper: nil
        case .pureWhite: .light
        case .amoledBlack: .dark
        }
    }
    static var current: AppCanvasStyle {
        let value = UserDefaults.standard.string(forKey: AppPreferences.appCanvasStyle)
        return AppCanvasStyle(rawValue: value ?? "") ?? .paper
    }
}

private struct AppCanvasStyleKey: EnvironmentKey {
    static let defaultValue = AppCanvasStyle.current
}

extension EnvironmentValues {
    var appCanvasStyle: AppCanvasStyle {
        get { self[AppCanvasStyleKey.self] }
        set { self[AppCanvasStyleKey.self] = newValue }
    }
}

extension Font {
    static func quickMailDisplay(_ size: CGFloat, relativeTo style: TextStyle = .largeTitle) -> Font {
        .system(size: size, weight: .bold, design: .default)
    }
    static func quickMailBody(_ size: CGFloat = 17, relativeTo style: TextStyle = .body) -> Font {
        .system(style, design: .default, weight: .regular)
    }
    static func quickMailSemibold(_ size: CGFloat = 17, relativeTo style: TextStyle = .body) -> Font {
        .system(style, design: .default, weight: .semibold)
    }
    static func quickMailBold(_ size: CGFloat = 17, relativeTo style: TextStyle = .body) -> Font {
        .system(style, design: .default, weight: .bold)
    }
}

enum QuickMailDesign {
    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let xxxl: CGFloat = 32
    }
    enum Radius {
        static let control: CGFloat = 10
        static let card: CGFloat = 14
        static let panel: CGFloat = 20
    }
    enum Layout {
        static let readableWidth: CGFloat = 720
        static let horizontalMargin: CGFloat = 16
        static let minimumHitTarget: CGFloat = 44
    }
    enum Typography {
        static var hero: Font { .quickMailDisplay(42) }
        static var sectionTitle: Font { .quickMailDisplay(25, relativeTo: .title3) }
        static var subject: Font { .quickMailDisplay(31, relativeTo: .title2) }
        static var rowPrimary: Font { .quickMailSemibold(17) }
        static var rowSecondary: Font { .quickMailBody(15, relativeTo: .subheadline) }
        static var body: Font { .quickMailBody() }
        static var metadata: Font { .quickMailBody(13, relativeTo: .caption) }
        static var micro: Font { .quickMailBold(11, relativeTo: .caption2) }
    }
    enum Palette {
        static var paper: Color { resolvedCanvas(.paper) }
        static var paperRaised: Color { resolvedCanvas(.raised) }
        static var paperGrouped: Color { resolvedCanvas(.grouped) }
        static var ink: Color { resolvedInk(muted: false) }
        static var inkMuted: Color { resolvedInk(muted: true) }
        static let signalInk = dynamic(
            light: UIColor(red: 0.080, green: 0.090, blue: 0.300, alpha: 1),
            dark: UIColor(red: 0.620, green: 0.700, blue: 1.000, alpha: 1)
        )
        static let floatingActionTint = signalInk
        static let sage = dynamic(
            light: UIColor(red: 0.204, green: 0.400, blue: 0.318, alpha: 1),
            dark: UIColor(red: 0.490, green: 0.710, blue: 0.596, alpha: 1)
        )
        static let sageStrong = dynamic(
            light: UIColor(red: 0.133, green: 0.310, blue: 0.239, alpha: 1),
            dark: UIColor(red: 0.600, green: 0.800, blue: 0.694, alpha: 1)
        )
        static let sageWash = dynamic(
            light: UIColor(red: 0.855, green: 0.910, blue: 0.875, alpha: 1),
            dark: UIColor(red: 0.125, green: 0.212, blue: 0.169, alpha: 1)
        )
        static var hairline: Color { resolvedRule }
        static var canvas: Color { paper }
        static var surface: Color { paperRaised }
        static var groupedSurface: Color { paperGrouped }
        static var raisedSurface: Color { paperRaised }
        static var fill: Color {
            switch AppCanvasStyle.current {
            case .amoledBlack: Color.white.opacity(0.12)
            case .pureWhite: Color.black.opacity(0.07)
            case .paper: ink.opacity(0.07)
            }
        }
        static var separator: Color { hairline }
        static var primaryText: Color { ink }
        static var secondaryText: Color { inkMuted }

        private enum Surface { case grouped, paper, raised }
        private static func resolvedCanvas(_ surface: Surface) -> Color {
            switch AppCanvasStyle.current {
            case .pureWhite:
                switch surface {
                case .grouped, .paper: .white
                case .raised: Color(red: 0.985, green: 0.985, blue: 0.985)
                }
            case .amoledBlack:
                switch surface {
                case .grouped, .paper: .black
                case .raised: Color(red: 0.055, green: 0.055, blue: 0.060)
                }
            case .paper:
                switch surface {
                case .grouped:
                    dynamic(light: UIColor(red: 244/255, green: 241/255, blue: 233/255, alpha: 1), dark: UIColor(red: 15/255, green: 19/255, blue: 21/255, alpha: 1))
                case .paper:
                    dynamic(light: UIColor(red: 250/255, green: 248/255, blue: 242/255, alpha: 1), dark: UIColor(red: 21/255, green: 25/255, blue: 27/255, alpha: 1))
                case .raised:
                    dynamic(light: UIColor(red: 255/255, green: 253/255, blue: 248/255, alpha: 1), dark: UIColor(red: 29/255, green: 34/255, blue: 37/255, alpha: 1))
                }
            }
        }
        private static func resolvedInk(muted: Bool) -> Color {
            switch AppCanvasStyle.current {
            case .pureWhite:
                muted ? Color(red: 0.34, green: 0.36, blue: 0.39) : Color(red: 0.055, green: 0.065, blue: 0.075)
            case .amoledBlack:
                muted ? Color(red: 0.68, green: 0.70, blue: 0.73) : Color(red: 0.96, green: 0.96, blue: 0.97)
            case .paper:
                muted
                    ? dynamic(light: UIColor(red: 91/255, green: 92/255, blue: 88/255, alpha: 1), dark: UIColor(red: 177/255, green: 181/255, blue: 183/255, alpha: 1))
                    : dynamic(light: UIColor(red: 28/255, green: 29/255, blue: 27/255, alpha: 1), dark: UIColor(red: 239/255, green: 237/255, blue: 231/255, alpha: 1))
            }
        }
        private static var resolvedRule: Color {
            switch AppCanvasStyle.current {
            case .pureWhite: Color.black.opacity(0.14)
            case .amoledBlack: Color.white.opacity(0.18)
            case .paper: dynamic(light: UIColor.black.withAlphaComponent(0.12), dark: UIColor.white.withAlphaComponent(0.16))
            }
        }
        private static func dynamic(light: UIColor, dark: UIColor) -> Color {
            Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? dark : light })
        }
    }
    enum Motion {
        static let press = Animation.easeOut(duration: 0.10)
        static let selection = Animation.easeInOut(duration: 0.16)
        static let stateChange = Animation.snappy(duration: 0.26, extraBounce: 0)
        static let insertion = Animation.spring(duration: 0.34, bounce: 0.08)
        static let dismissal = Animation.easeInOut(duration: 0.22)
        static func resolved(_ animation: Animation, reduceMotion: Bool) -> Animation? { reduceMotion ? nil : animation }
        static func revealTransition(reduceMotion: Bool) -> AnyTransition { reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity) }
        static func dismissalTransition(reduceMotion: Bool) -> AnyTransition { reduceMotion ? .opacity : .move(edge: .trailing).combined(with: .opacity) }
    }
    static let contentMaxWidth = Layout.readableWidth
    static var compactCornerRadius: CGFloat { Radius.card }
}

private struct QuickMailStyleRootModifier: ViewModifier {
    func body(content: Content) -> some View { content.font(.body).foregroundStyle(QuickMailDesign.Palette.primaryText).tint(Color.accentColor) }
}
private struct QuickMailPageSurfaceModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.background(QuickMailDesign.Palette.paper).toolbarBackground(QuickMailDesign.Palette.paper, for: .navigationBar).toolbarBackground(.visible, for: .navigationBar)
    }
}
private struct QuickMailListRowSurfaceModifier: ViewModifier { func body(content: Content) -> some View { content } }
private struct QuickMailBarSurfaceModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.background(QuickMailDesign.Palette.paperRaised).overlay(alignment: .top) { Rectangle().fill(QuickMailDesign.Palette.separator).frame(height: 1 / UIScreen.main.scale) }
    }
}
private struct QuickMailFormSurfaceModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.scrollContentBackground(.hidden).background(QuickMailDesign.Palette.paperGrouped).toolbarBackground(QuickMailDesign.Palette.paper, for: .navigationBar).toolbarBackground(.visible, for: .navigationBar)
    }
}
extension View {
    func quickMailStyleRoot() -> some View { modifier(QuickMailStyleRootModifier()) }
    func quickMailPageSurface() -> some View { modifier(QuickMailPageSurfaceModifier()) }
    func quickMailFormSurface() -> some View { modifier(QuickMailFormSurfaceModifier()) }
    func quickMailListRowSurface() -> some View { modifier(QuickMailListRowSurfaceModifier()) }
    func quickMailBarSurface() -> some View { modifier(QuickMailBarSurfaceModifier()) }
}

struct QuickMailPanelShape: Shape {
    var normalCornerRadius: CGFloat = QuickMailDesign.Radius.card
    func path(in rect: CGRect) -> Path { RoundedRectangle(cornerRadius: normalCornerRadius, style: .continuous).path(in: rect) }
}
struct QuickMailCapsuleShape: Shape { func path(in rect: CGRect) -> Path { Capsule().path(in: rect) } }

struct QuickMailForm<Content: View>: View {
    private let hidesRowSeparators: Bool
    @ViewBuilder let content: () -> Content
    init(hidesRowSeparators: Bool = false, @ViewBuilder content: @escaping () -> Content) { self.hidesRowSeparators = hidesRowSeparators; self.content = content }
    var body: some View {
        Form { if hidesRowSeparators { content().listRowSeparator(.hidden) } else { content() } }
            .environment(\.defaultMinListRowHeight, 44)
    }
}
struct QuickMailRule: View {
    var body: some View { Rectangle().fill(QuickMailDesign.Palette.separator).frame(height: 1 / UIScreen.main.scale).accessibilityHidden(true) }
}
struct QuickMailMark: View {
    var size: Font = .largeTitle
    var body: some View { Image(systemName: "paperplane.fill").font(size.weight(.medium)).symbolRenderingMode(.monochrome).accessibilityHidden(true) }
}
struct ParticipantMonogram: View {
    let name: String
    var isEmphasized = false
    var size: CGFloat = 40
    @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1
    var body: some View {
        Text(initials).font(monogramFont.weight(isEmphasized ? .semibold : .medium))
            .foregroundStyle(isEmphasized ? QuickMailDesign.Palette.primaryText : QuickMailDesign.Palette.secondaryText)
            .minimumScaleFactor(0.75).lineLimit(1).frame(width: diameter, height: diameter)
            .background(Circle().fill(QuickMailDesign.Palette.sageWash))
            .overlay { Circle().strokeBorder(QuickMailDesign.Palette.separator.opacity(0.45), lineWidth: 0.5) }
            .accessibilityHidden(true)
    }
    private var diameter: CGFloat { min(size * scale, size * 1.35) }
    private var monogramFont: Font { switch size { case ..<40: .caption; case ..<48: .subheadline; default: .headline } }
    private var initials: String {
        let visibleName = name.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "@", maxSplits: 1).first ?? ""
        let words = visibleName.split { $0.isWhitespace || $0 == "." || $0 == "_" || $0 == "-" || $0 == "+" }.filter { !$0.isEmpty }
        guard let first = words.first?.first else { return "?" }
        if words.count > 1, let last = words.last?.first { return String([first, last]).uppercased() }
        return String(first).uppercased()
    }
}

enum MetadataPillTone: Sendable {
    case neutral, info, success, warning, critical
    fileprivate var foreground: Color {
        switch self { case .neutral: QuickMailDesign.Palette.secondaryText; case .info: .accentColor; case .success: Color(uiColor: .systemGreen); case .warning: Color(uiColor: .systemOrange); case .critical: Color(uiColor: .systemRed) }
    }
}
struct MetadataPill: View {
    let title: String
    let systemImage: String
    var tint: Color = .secondary
    private var tone: MetadataPillTone?
    init(title: String, systemImage: String, tint: Color = .secondary) { self.title = title; self.systemImage = systemImage; self.tint = tint; tone = nil }
    init(title: String, systemImage: String, tone: MetadataPillTone) { self.title = title; self.systemImage = systemImage; tint = tone.foreground; self.tone = tone }
    var body: some View {
        Label(title, systemImage: systemImage).font(QuickMailDesign.Typography.micro).foregroundStyle(tone?.foreground ?? tint)
            .padding(.horizontal, QuickMailDesign.Spacing.sm).padding(.vertical, QuickMailDesign.Spacing.xs)
            .background(QuickMailDesign.Palette.fill, in: QuickMailCapsuleShape())
            .overlay { QuickMailCapsuleShape().stroke(QuickMailDesign.Palette.separator.opacity(0.35), lineWidth: 0.5) }
            .accessibilityElement(children: .combine)
    }
}
struct QuickMailAccountHeader: View {
    let name: String
    let email: String
    var server: String?
    var body: some View {
        HStack(spacing: QuickMailDesign.Spacing.md) {
            ParticipantMonogram(name: name, size: 48)
            VStack(alignment: .leading, spacing: QuickMailDesign.Spacing.xxs) {
                Text(name).font(.quickMailSemibold(17, relativeTo: .headline)).lineLimit(1)
                Text(email).font(QuickMailDesign.Typography.rowSecondary).foregroundStyle(QuickMailDesign.Palette.secondaryText).lineLimit(1)
                if let server, !server.isEmpty { Text(server).font(QuickMailDesign.Typography.metadata).foregroundStyle(QuickMailDesign.Palette.secondaryText).lineLimit(1) }
            }
        }.padding(.vertical, QuickMailDesign.Spacing.xs).accessibilityElement(children: .combine)
    }
}
