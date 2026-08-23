import SwiftUI

/// Visual emphasis for an action that floats above app content.
enum FloatingActionProminence: Sendable {
    case standard
    case prominent
}

/// A system-styled action for the small number of controls that float above content.
///
/// Keep actions in a navigation bar or toolbar as plain `Button` values so the system
/// can style the surrounding bar. This component is for standalone floating actions.
struct FloatingActionButton<Label: View>: View {
    private let role: ButtonRole?
    private let prominence: FloatingActionProminence
    private let action: () -> Void
    private let label: () -> Label

    init(
        role: ButtonRole? = nil,
        prominence: FloatingActionProminence = .standard,
        action: @escaping () -> Void,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.role = role
        self.prominence = prominence
        self.action = action
        self.label = label
    }

    var body: some View {
        Button(role: role, action: action, label: label)
            .modifier(PlatformFloatingButtonStyle(prominence: prominence))
    }
}

extension FloatingActionButton where Label == SwiftUI.Label<Text, Image> {
    init(
        _ titleKey: LocalizedStringKey,
        systemImage: String,
        role: ButtonRole? = nil,
        prominence: FloatingActionProminence = .standard,
        action: @escaping () -> Void
    ) {
        self.init(role: role, prominence: prominence, action: action) {
            Label(titleKey, systemImage: systemImage)
        }
    }
}

/// Coordinates adjacent Liquid Glass controls on iOS 26 and later.
/// Earlier systems retain their normal SwiftUI layout and styling.
struct FloatingControlGroup<Content: View>: View {
    private let spacing: CGFloat?
    private let content: () -> Content

    init(
        spacing: CGFloat? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.spacing = spacing
        self.content = content
    }

    @ViewBuilder
    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) {
                content()
            }
        } else {
            content()
        }
    }
}

/// A full-width primary action that adopts the platform's current material.
/// Unlike `FloatingActionButton`, this is intended for actions inside a flow.
struct PlatformPrimaryActionButton<Label: View>: View {
    private let action: () -> Void
    private let label: () -> Label

    init(action: @escaping () -> Void, @ViewBuilder label: @escaping () -> Label) {
        self.action = action
        self.label = label
    }

    var body: some View {
        Button(action: action, label: label)
            .modifier(PlatformPrimaryActionStyle())
    }
}

private struct PlatformPrimaryActionStyle: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.buttonStyle(.glassProminent)
        } else {
            content.buttonStyle(.borderedProminent)
        }
    }
}

private struct PlatformFloatingButtonStyle: ViewModifier {
    let prominence: FloatingActionProminence

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            switch prominence {
            case .standard:
                content.buttonStyle(.glass)
            case .prominent:
                content.buttonStyle(.glassProminent)
            }
        } else {
            switch prominence {
            case .standard:
                content.buttonStyle(.bordered)
            case .prominent:
                content.buttonStyle(.borderedProminent)
            }
        }
    }
}
