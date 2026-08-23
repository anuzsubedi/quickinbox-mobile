import SwiftUI

/// Shared visual language for QuickMail's restrained, text-first interface.
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
        static let hero: Font = .title.weight(.bold)
        static let sectionTitle: Font = .title3.weight(.semibold)
        static let subject: Font = .title2.weight(.semibold)
        static let rowPrimary: Font = .body
        static let rowSecondary: Font = .subheadline
        static let body: Font = .body
        static let metadata: Font = .caption
        static let micro: Font = .caption2.weight(.medium)
    }

    enum Palette {
        /// System reading surfaces keep mail crisp in every appearance mode.
        static let paper = Color(uiColor: .systemBackground)
        static let paperRaised = Color(uiColor: .secondarySystemBackground)
        static let paperGrouped = Color(uiColor: .systemGroupedBackground)

        /// Semantic reading ink remains distinct from the branded navigation field.
        static let ink = Color(uiColor: .label)
        static let inkMuted = Color(uiColor: .secondaryLabel)
        static let signalInk = dynamic(
            light: UIColor(red: 0.080, green: 0.090, blue: 0.300, alpha: 1),
            dark: UIColor(red: 0.105, green: 0.120, blue: 0.360, alpha: 1)
        )

        /// The single brand accent for selection, unread state, and primary action.
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
        static let hairline = Color(uiColor: .separator)

        // Compatibility roles used throughout the existing feature views.
        static let canvas = paper
        static let surface = paperRaised
        static let groupedSurface = paperGrouped
        static let raisedSurface = paperRaised
        static let fill = Color(uiColor: .tertiarySystemFill)
        static let separator = hairline
        static let primaryText = ink
        static let secondaryText = inkMuted

        private static func dynamic(light: UIColor, dark: UIColor) -> Color {
            Color(uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark ? dark : light
            })
        }
    }

    /// A compact motion vocabulary for consistent, quiet feedback across the app.
    enum Motion {
        static let press = Animation.easeOut(duration: 0.10)
        static let selection = Animation.easeInOut(duration: 0.16)
        static let stateChange = Animation.snappy(duration: 0.26, extraBounce: 0)
        static let insertion = Animation.spring(duration: 0.34, bounce: 0.08)
        static let dismissal = Animation.easeInOut(duration: 0.22)

        /// Removes spatial motion rather than merely speeding it up.
        static func resolved(_ animation: Animation, reduceMotion: Bool) -> Animation? {
            reduceMotion ? nil : animation
        }

        static func revealTransition(reduceMotion: Bool) -> AnyTransition {
            reduceMotion
                ? .opacity
                : .move(edge: .top).combined(with: .opacity)
        }

        static func dismissalTransition(reduceMotion: Bool) -> AnyTransition {
            reduceMotion
                ? .opacity
                : .move(edge: .trailing).combined(with: .opacity)
        }
    }

    // Compatibility names used by existing feature views.
    static let contentMaxWidth = Layout.readableWidth
    static let compactCornerRadius = Radius.card
}

struct QuickMailMark: View {
    var size: Font = .largeTitle

    var body: some View {
        Image(systemName: "paperplane.fill")
            .font(size.weight(.medium))
            .symbolRenderingMode(.monochrome)
            .accessibilityHidden(true)
    }
}

struct ParticipantMonogram: View {
    let name: String
    var isEmphasized = false
    var size: CGFloat = 40

    @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1

    var body: some View {
        Text(initials)
            .font(monogramFont.weight(isEmphasized ? .semibold : .medium))
            .foregroundStyle(
                isEmphasized
                    ? QuickMailDesign.Palette.primaryText
                    : QuickMailDesign.Palette.secondaryText
            )
            .minimumScaleFactor(0.75)
            .lineLimit(1)
            .frame(width: diameter, height: diameter)
            .background(QuickMailDesign.Palette.sageWash, in: Circle())
            .overlay {
                Circle()
                    .strokeBorder(
                        QuickMailDesign.Palette.separator.opacity(0.45),
                        lineWidth: 0.5
                    )
            }
            .accessibilityHidden(true)
    }

    private var diameter: CGFloat {
        min(size * scale, size * 1.35)
    }

    private var monogramFont: Font {
        switch size {
        case ..<40: .caption
        case ..<48: .subheadline
        default: .headline
        }
    }

    private var initials: String {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let visibleName = trimmedName.split(separator: "@", maxSplits: 1).first ?? ""
        let words = visibleName
            .split {
                $0.isWhitespace || $0 == "." || $0 == "_" || $0 == "-" || $0 == "+"
            }
            .filter { !$0.isEmpty }

        guard let first = words.first?.first else { return "?" }
        let characters: [Character]
        if words.count > 1, let last = words.last?.first {
            characters = [first, last]
        } else {
            characters = [first]
        }
        return String(characters).uppercased()
    }
}

enum MetadataPillTone: Sendable {
    case neutral
    case info
    case success
    case warning
    case critical

    fileprivate var foreground: Color {
        switch self {
        case .neutral: QuickMailDesign.Palette.secondaryText
        case .info: .accentColor
        case .success: Color(uiColor: .systemGreen)
        case .warning: Color(uiColor: .systemOrange)
        case .critical: Color(uiColor: .systemRed)
        }
    }
}

struct MetadataPill: View {
    let title: String
    let systemImage: String
    var tint: Color = .secondary

    private var tone: MetadataPillTone?

    init(title: String, systemImage: String, tint: Color = .secondary) {
        self.title = title
        self.systemImage = systemImage
        self.tint = tint
        self.tone = nil
    }

    init(title: String, systemImage: String, tone: MetadataPillTone) {
        self.title = title
        self.systemImage = systemImage
        self.tint = tone.foreground
        self.tone = tone
    }

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(QuickMailDesign.Typography.micro)
            .foregroundStyle(tone?.foreground ?? tint)
            .padding(.horizontal, QuickMailDesign.Spacing.sm)
            .padding(.vertical, QuickMailDesign.Spacing.xs)
            .background(QuickMailDesign.Palette.fill, in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(
                        QuickMailDesign.Palette.separator.opacity(0.35),
                        lineWidth: 0.5
                    )
            }
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
                Text(name)
                    .font(.headline)
                    .lineLimit(1)
                Text(email)
                    .font(QuickMailDesign.Typography.rowSecondary)
                    .foregroundStyle(QuickMailDesign.Palette.secondaryText)
                    .lineLimit(1)
                if let server, !server.isEmpty {
                    Text(server)
                        .font(QuickMailDesign.Typography.metadata)
                        .foregroundStyle(QuickMailDesign.Palette.secondaryText)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, QuickMailDesign.Spacing.xs)
        .accessibilityElement(children: .combine)
    }
}
