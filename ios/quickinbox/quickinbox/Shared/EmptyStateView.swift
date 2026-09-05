import SwiftUI

struct EmptyStateAction: Identifiable {
    var id: String { title }
    let title: String
    var isProminent = false
    var role: ButtonRole?
    let handler: () -> Void

    init(
        _ title: String,
        isProminent: Bool = false,
        role: ButtonRole? = nil,
        handler: @escaping () -> Void
    ) {
        self.title = title
        self.isProminent = isProminent
        self.role = role
        self.handler = handler
    }
}
enum EmptyStateTone {
    case accent
    case warning
    case muted

    fileprivate var iconStyle: AnyShapeStyle {
        switch self {
        case .accent: AnyShapeStyle(QuickInboxDesign.Palette.interactiveTint)
        case .warning: AnyShapeStyle(QuickInboxDesign.Palette.warning)
        case .muted: AnyShapeStyle(QuickInboxDesign.Palette.secondaryText)
        }
    }

    fileprivate var washStyle: AnyShapeStyle {
        switch self {
        case .accent:
            AnyShapeStyle(QuickInboxDesign.Palette.sageWash)
        case .warning:
            AnyShapeStyle(QuickInboxDesign.Palette.warning.opacity(0.12))
        case .muted:
            AnyShapeStyle(QuickInboxDesign.Palette.fill)
        }
    }
}
enum EmptyStateLayout {
    /// Full-screen centered composition on paper.
    case page
    /// Raised card on grouped paper (split-view / error screens).
    case card
    /// Inside a scroll surface without forcing a page background.
    case embedded
    /// Compact panel row for settings sections.
    case inline
}

struct EmptyStateGlyph: View {
    let systemImage: String
    var tone: EmptyStateTone = .accent
    var size: CGFloat = 92
    var iconSize: CGFloat = 34

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        ZStack {
            Circle()
                .fill(tone.washStyle)
                .frame(width: size, height: size)
                .overlay {
                    Circle()
                        .strokeBorder(QuickInboxDesign.Palette.separator.opacity(0.4), lineWidth: 0.5)
                }

            Image(systemName: systemImage)
                .font(.system(size: iconSize, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tone.iconStyle)
        }
        .scaleEffect(appeared || reduceMotion ? 1 : 0.92)
        .opacity(appeared || reduceMotion ? 1 : 0)
        .accessibilityHidden(true)
        .onAppear {
            withAnimation(
                QuickInboxDesign.Motion.resolved(
                    QuickInboxDesign.Motion.insertion,
                    reduceMotion: reduceMotion
                )
            ) {
                appeared = true
            }
        }
    }
}

struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String
    var tone: EmptyStateTone = .accent
    var layout: EmptyStateLayout = .page
    var actions: [EmptyStateAction] = []

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var contentAppeared = false

    var body: some View {
        switch layout {
        case .page:
            pageBody
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(QuickInboxDesign.Palette.paper)
        case .card:
            cardBody
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(QuickInboxDesign.Palette.paperGrouped)
        case .embedded:
            contentStack(glyphSize: 96, iconSize: 36, spacing: 18)
                .padding(.horizontal, QuickInboxDesign.Spacing.xxxl)
                .padding(.vertical, QuickInboxDesign.Spacing.xxl)
                .frame(maxWidth: .infinity)
        case .inline:
            inlineBody
        }
    }

    private var pageBody: some View {
        contentStack(glyphSize: 96, iconSize: 36, spacing: 18)
            .padding(.horizontal, QuickInboxDesign.Spacing.xxxl)
            .padding(.vertical, QuickInboxDesign.Spacing.xxl)
    }

    private var cardBody: some View {
        contentStack(glyphSize: 92, iconSize: 34, spacing: 16)
            .padding(28)
            .quickInboxCard(padding: 0)
            .padding(24)
    }

    private var inlineBody: some View {
        HStack(alignment: .top, spacing: 14) {
            EmptyStateGlyph(
                systemImage: systemImage,
                tone: tone,
                size: 44,
                iconSize: 18
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(QuickInboxDesign.Palette.primaryText)
                Text(message)
                    .font(QuickInboxDesign.Typography.rowSecondary)
                    .foregroundStyle(QuickInboxDesign.Palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                if !actions.isEmpty {
                    actionRow
                        .padding(.top, 8)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func contentStack(glyphSize: CGFloat, iconSize: CGFloat, spacing: CGFloat) -> some View {
        VStack(spacing: spacing) {
            EmptyStateGlyph(
                systemImage: systemImage,
                tone: tone,
                size: glyphSize,
                iconSize: iconSize
            )

            VStack(spacing: 8) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(QuickInboxDesign.Palette.primaryText)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(QuickInboxDesign.Palette.secondaryText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
            }
            .opacity(contentAppeared || reduceMotion ? 1 : 0)
            .offset(y: contentAppeared || reduceMotion ? 0 : 6)

            if !actions.isEmpty {
                actionRow
                    .padding(.top, 4)
                    .opacity(contentAppeared || reduceMotion ? 1 : 0)
            }
        }
        .frame(maxWidth: QuickInboxDesign.contentMaxWidth)
        .accessibilityElement(children: .contain)
        .onAppear {
            withAnimation(
                QuickInboxDesign.Motion.resolved(
                    .easeOut(duration: 0.35).delay(0.05),
                    reduceMotion: reduceMotion
                )
            ) {
                contentAppeared = true
            }
        }
    }

    @ViewBuilder
    private var actionRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                ForEach(actions) { actionButton(for: $0) }
            }
            VStack(spacing: 10) {
                ForEach(actions) { actionButton(for: $0) }
            }
        }
    }

    private func actionButton(for action: EmptyStateAction) -> some View {
        Button(role: action.role, action: action.handler) {
            Text(action.title)
                .frame(minWidth: layout == .inline ? 0 : 120)
        }
        .modifier(EmptyStateActionStyle(isProminent: action.isProminent, role: action.role))
    }
}

private struct EmptyStateActionStyle: ViewModifier {
    let isProminent: Bool
    let role: ButtonRole?

    func body(content: Content) -> some View {
        if isProminent {
            content.quickInboxProminentButtonStyle()
        } else if role == .destructive {
            content.quickInboxDestructiveButtonStyle()
        } else {
            content.quickInboxBorderedButtonStyle()
        }
    }
}
