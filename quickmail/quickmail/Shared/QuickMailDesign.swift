import SwiftUI
import UIKit

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
        static let paper = AppThemeColorStyle(.paper)
        static let paperRaised = AppThemeColorStyle(.raised)
        static let paperGrouped = AppThemeColorStyle(.grouped)
        static let ink = AppThemeColorStyle(.primaryText)
        static let inkMuted = AppThemeColorStyle(.secondaryText)
        static let signalInk = AppThemeColorStyle(.signalInk)
        static let floatingActionTint = signalInk
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
    fileprivate var foreground: AnyShapeStyle {
        switch self {
        case .neutral: AnyShapeStyle(QuickMailDesign.Palette.secondaryText)
        case .info: AnyShapeStyle(Color.accentColor)
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
            .font(QuickMailDesign.Typography.micro)
            .foregroundStyle(tone?.foreground ?? AnyShapeStyle(tint))
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
