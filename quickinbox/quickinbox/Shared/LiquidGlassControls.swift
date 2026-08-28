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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @GestureState private var isPressed = false

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
            .scaleEffect(isPressed && !reduceMotion ? 0.97 : 1)
            .opacity(isPressed && reduceMotion ? 0.82 : 1)
            .animation(
                QuickInboxDesign.Motion.resolved(
                    QuickInboxDesign.Motion.press,
                    reduceMotion: reduceMotion
                ),
                value: isPressed
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .updating($isPressed) { _, pressed, _ in
                        pressed = true
                    }
            )
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

/// Preserves the shared layout used by floating controls.
///
/// A `GlassEffectContainer` is unnecessary for the current single-action call sites.
/// Add one at the call site only when multiple adjacent glass effects need to blend
/// or transition together.
struct FloatingControlGroup<Content: View>: View {
    private let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        content()
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

private struct AdaptiveProminentButtonModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .buttonStyle(.borderedProminent)
            .foregroundStyle(QuickInboxDesign.Palette.onInteractive)
    }
}

private struct AdaptiveBorderedButtonModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.buttonStyle(.bordered)
    }
}

extension View {
    func quickInboxProminentButtonStyle() -> some View {
        modifier(AdaptiveProminentButtonModifier())
    }

    func quickInboxBorderedButtonStyle() -> some View {
        modifier(AdaptiveBorderedButtonModifier())
    }

}

private struct AdaptiveDisclosureButtonModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.buttonStyle(.plain)
    }
}

extension View {
    func quickInboxDisclosureButtonStyle() -> some View {
        modifier(AdaptiveDisclosureButtonModifier())
    }
}

private struct AdaptiveDestructiveButtonModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.buttonStyle(.bordered)
    }
}

extension View {
    func quickInboxDestructiveButtonStyle() -> some View {
        modifier(AdaptiveDestructiveButtonModifier())
    }

}
