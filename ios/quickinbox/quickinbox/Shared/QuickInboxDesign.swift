import SwiftUI
import UIKit

extension Font {
    static func quickInboxDisplay(_ size: CGFloat, relativeTo style: TextStyle = .largeTitle) -> Font {
        .system(size: size, weight: .bold, design: .default)
    }
    static func quickInboxBody(_ size: CGFloat = 17, relativeTo style: TextStyle = .body) -> Font {
        .system(style, design: .default, weight: .regular)
    }
    static func quickInboxSemibold(_ size: CGFloat = 17, relativeTo style: TextStyle = .body) -> Font {
        .system(style, design: .default, weight: .semibold)
    }
    static func quickInboxBold(_ size: CGFloat = 17, relativeTo style: TextStyle = .body) -> Font {
        .system(style, design: .default, weight: .bold)
    }

    /// Bricolage Grotesque display face used by onboarding surfaces. Scales with Dynamic Type.
    static func onboardingBrand(_ size: CGFloat, _ weight: Font.Weight = .regular, relativeTo style: TextStyle = .body) -> Font {
        .custom(onboardingBrandName(weight), size: size, relativeTo: style)
    }

    private static func onboardingBrandName(_ weight: Font.Weight) -> String {
        switch weight {
        case .semibold, .bold, .heavy, .black: "BricolageGrotesque-SemiBold"
        default: "BricolageGrotesque-Medium"
        }
    }
}

enum QuickInboxDesign {
    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let xxxl: CGFloat = 32
        static let page: CGFloat = 20
    }
    enum Radius {
        static let control: CGFloat = 14
        static let card: CGFloat = 18
        static let panel: CGFloat = 24
    }
    enum Layout {
        static let readableWidth: CGFloat = 720
        static let horizontalMargin: CGFloat = 16
        static let minimumHitTarget: CGFloat = 44
    }
    enum Typography {
        static var hero: Font { .quickInboxDisplay(42) }
        static var sectionTitle: Font { .quickInboxDisplay(25, relativeTo: .title3) }
        static var subject: Font { .quickInboxDisplay(31, relativeTo: .title2) }
        static var rowPrimary: Font { .quickInboxSemibold(17) }
        static var rowSecondary: Font { .quickInboxBody(15, relativeTo: .subheadline) }
        static var body: Font { .quickInboxBody() }
        static var metadata: Font { .quickInboxBody(13, relativeTo: .caption) }
        static var micro: Font { .quickInboxBold(11, relativeTo: .caption2) }
    }
    enum Palette {
        static let paper = AppThemeColorStyle(.paper)
        static let paperRaised = AppThemeColorStyle(.raised)
        static let paperGrouped = AppThemeColorStyle(.grouped)
        static let ink = AppThemeColorStyle(.primaryText)
        static let inkMuted = AppThemeColorStyle(.secondaryText)
        static let signalInk = AppThemeColorStyle(.signalInk)
        static let interactiveTint = AppThemeColorStyle(.interactiveTint)
        static let onInteractive = AppThemeColorStyle(.onInteractive)
        static let floatingActionTint = interactiveTint
        static let sage = AppThemeColorStyle(.sage)
        static let sageStrong = AppThemeColorStyle(.sageStrong)
        static let sageWash = AppThemeColorStyle(.sageWash)
        static let hairline = AppThemeColorStyle(.separator)
        static let canvas = paper
        static let surface = paperRaised
        static let groupedSurface = paperGrouped
        static let raisedSurface = paperRaised
        static let fill = AppThemeColorStyle(.fill)
        static let separator = hairline
        static let primaryText = ink
        static let secondaryText = inkMuted
    }
    enum Motion {
        static let press = Animation.spring(duration: 0.18, bounce: 0.18)
        static let selection = Animation.easeInOut(duration: 0.18)
        static let stateChange = Animation.snappy(duration: 0.3, extraBounce: 0.04)
        static let insertion = Animation.spring(duration: 0.4, bounce: 0.12)
        static let dismissal = Animation.easeInOut(duration: 0.22)
        static func resolved(_ animation: Animation, reduceMotion: Bool) -> Animation? { reduceMotion ? nil : animation }
        static func revealTransition(reduceMotion: Bool) -> AnyTransition { reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity) }
        static func dismissalTransition(reduceMotion: Bool) -> AnyTransition { reduceMotion ? .opacity : .move(edge: .trailing).combined(with: .opacity) }
    }
    static let contentMaxWidth = Layout.readableWidth
    static var compactCornerRadius: CGFloat { Radius.card }
}

private struct QuickInboxStyleRootModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.body)
            .foregroundStyle(QuickInboxDesign.Palette.primaryText)
            .tint(QuickInboxDesign.Palette.interactiveTint)
    }
}
private struct QuickInboxPageSurfaceModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.background(QuickInboxDesign.Palette.paper).toolbarBackground(QuickInboxDesign.Palette.paper, for: .navigationBar).toolbarBackground(.visible, for: .navigationBar)
    }
}
private struct QuickInboxListRowSurfaceModifier: ViewModifier { func body(content: Content) -> some View { content } }
private struct QuickInboxBarSurfaceModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.background(QuickInboxDesign.Palette.paperRaised).overlay(alignment: .top) { Rectangle().fill(QuickInboxDesign.Palette.separator).frame(height: 1 / UIScreen.main.scale) }
    }
}
private struct QuickInboxFormSurfaceModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.scrollContentBackground(.hidden).background(QuickInboxDesign.Palette.paperGrouped).toolbarBackground(QuickInboxDesign.Palette.paper, for: .navigationBar).toolbarBackground(.visible, for: .navigationBar)
    }
}
extension View {
    func quickInboxStyleRoot() -> some View { modifier(QuickInboxStyleRootModifier()) }
    func quickInboxPageSurface() -> some View { modifier(QuickInboxPageSurfaceModifier()) }
    func quickInboxFormSurface() -> some View { modifier(QuickInboxFormSurfaceModifier()) }
    func quickInboxListRowSurface() -> some View { modifier(QuickInboxListRowSurfaceModifier()) }
    func quickInboxBarSurface() -> some View { modifier(QuickInboxBarSurfaceModifier()) }
    func quickInboxCard(padding: CGFloat = QuickInboxDesign.Spacing.lg) -> some View {
        modifier(QuickInboxCardModifier(padding: padding))
    }
}

struct QuickInboxPanelShape: Shape {
    var normalCornerRadius: CGFloat = QuickInboxDesign.Radius.card
    func path(in rect: CGRect) -> Path { RoundedRectangle(cornerRadius: normalCornerRadius, style: .continuous).path(in: rect) }
}
struct QuickInboxCapsuleShape: Shape { func path(in rect: CGRect) -> Path { Capsule().path(in: rect) } }

struct QuickInboxCardModifier: ViewModifier {
    @Environment(\.appTheme) private var appTheme
    @Environment(\.colorScheme) private var colorScheme
    var padding: CGFloat = QuickInboxDesign.Spacing.lg

    func body(content: Content) -> some View {
        let palette = appTheme.palette(for: colorScheme)
        let shape = RoundedRectangle(cornerRadius: QuickInboxDesign.Radius.card, style: .continuous)
        content
            .padding(padding)
            .background(palette.raised, in: shape)
            .overlay { shape.stroke(palette.separator.opacity(0.5), lineWidth: 0.5) }
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.16 : 0.055), radius: 14, y: 5)
    }
}

struct QuickInboxPressButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.975 : 1)
            .opacity(isEnabled ? (configuration.isPressed ? 0.82 : 1) : 0.45)
            .animation(
                QuickInboxDesign.Motion.resolved(QuickInboxDesign.Motion.press, reduceMotion: reduceMotion),
                value: configuration.isPressed
            )
    }
}

struct AnimatedMailGlyph: View {
    var body: some View {
        EmptyStateGlyph(systemImage: "envelope.fill")
    }
}

struct QuickInboxForm<Content: View>: View {
    private let hidesRowSeparators: Bool
    @ViewBuilder let content: () -> Content
    init(hidesRowSeparators: Bool = false, @ViewBuilder content: @escaping () -> Content) { self.hidesRowSeparators = hidesRowSeparators; self.content = content }
    var body: some View {
        Form { if hidesRowSeparators { content().listRowSeparator(.hidden) } else { content() } }
            .environment(\.defaultMinListRowHeight, 44)
    }
}
struct QuickInboxRule: View {
    var body: some View { Rectangle().fill(QuickInboxDesign.Palette.separator).frame(height: 1 / UIScreen.main.scale).accessibilityHidden(true) }
}
struct QuickInboxMark: View {
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
            .foregroundStyle(isEmphasized ? QuickInboxDesign.Palette.primaryText : QuickInboxDesign.Palette.secondaryText)
            .minimumScaleFactor(0.75).lineLimit(1).frame(width: diameter, height: diameter)
            .background(Circle().fill(QuickInboxDesign.Palette.sageWash))
            .overlay { Circle().strokeBorder(QuickInboxDesign.Palette.separator.opacity(0.45), lineWidth: 0.5) }
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
    fileprivate var foreground: AnyShapeStyle {
        switch self {
        case .neutral: AnyShapeStyle(QuickInboxDesign.Palette.secondaryText)
        case .info: AnyShapeStyle(QuickInboxDesign.Palette.interactiveTint)
        case .success: AnyShapeStyle(Color(uiColor: .systemGreen))
        case .warning: AnyShapeStyle(Color(uiColor: .systemOrange))
        case .critical: AnyShapeStyle(Color(uiColor: .systemRed))
        }
    }
}
struct MetadataPill: View {
    let title: String
    let systemImage: String
    var tint: Color = .secondary
    private var tone: MetadataPillTone?
    init(title: String, systemImage: String, tint: Color = .secondary) { self.title = title; self.systemImage = systemImage; self.tint = tint; tone = nil }
    init(title: String, systemImage: String, tone: MetadataPillTone) { self.title = title; self.systemImage = systemImage; tint = .secondary; self.tone = tone }
    var body: some View {
        Label(title, systemImage: systemImage)
            .font(QuickInboxDesign.Typography.micro)
            .foregroundStyle(tone?.foreground ?? AnyShapeStyle(tint))
            .padding(.horizontal, QuickInboxDesign.Spacing.sm).padding(.vertical, QuickInboxDesign.Spacing.xs)
            .background(QuickInboxDesign.Palette.fill, in: QuickInboxCapsuleShape())
            .overlay { QuickInboxCapsuleShape().stroke(QuickInboxDesign.Palette.separator.opacity(0.35), lineWidth: 0.5) }
            .accessibilityElement(children: .combine)
    }
}
struct QuickInboxAccountHeader: View {
    let name: String
    let email: String
    var server: String?
    var body: some View {
        HStack(spacing: QuickInboxDesign.Spacing.md) {
            ParticipantMonogram(name: name, size: 48)
            VStack(alignment: .leading, spacing: QuickInboxDesign.Spacing.xxs) {
                Text(name).font(.quickInboxSemibold(17, relativeTo: .headline)).lineLimit(1)
                Text(email).font(QuickInboxDesign.Typography.rowSecondary).foregroundStyle(QuickInboxDesign.Palette.secondaryText).lineLimit(1)
                if let server, !server.isEmpty { Text(server).font(QuickInboxDesign.Typography.metadata).foregroundStyle(QuickInboxDesign.Palette.secondaryText).lineLimit(1) }
            }
        }.padding(.vertical, QuickInboxDesign.Spacing.xs).accessibilityElement(children: .combine)
    }
}
