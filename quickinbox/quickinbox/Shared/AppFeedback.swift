import UIKit

nonisolated enum AppFeedback {
    /// Semantic feedback keeps feature code independent of generator style choices.
    enum Event: Sendable {
        case selection
        case toggleConfirmed
        case moveConfirmed
        case destructiveConfirmed
        case messageSent
        case success
        case warning
        case error
    }

    @MainActor private static let notificationGenerator = UINotificationFeedbackGenerator()
    @MainActor private static let selectionGenerator = UISelectionFeedbackGenerator()
    @MainActor private static let lightImpactGenerator = UIImpactFeedbackGenerator(style: .light)
    @MainActor private static let mediumImpactGenerator = UIImpactFeedbackGenerator(style: .medium)

    @MainActor
    static func play(_ event: Event) {
        switch event {
        case .selection, .toggleConfirmed:
            selectionGenerator.prepare()
            selectionGenerator.selectionChanged()
        case .moveConfirmed:
            lightImpactGenerator.prepare()
            lightImpactGenerator.impactOccurred()
        case .destructiveConfirmed:
            mediumImpactGenerator.prepare()
            mediumImpactGenerator.impactOccurred()
        case .messageSent, .success:
            notify(.success)
        case .warning:
            notify(.warning)
        case .error:
            notify(.error)
        }
    }

    @MainActor
    static func success() {
        play(.success)
    }

    @MainActor
    static func error() {
        play(.error)
    }

    @MainActor
    static func selection() {
        play(.selection)
    }

    @MainActor
    private static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        notificationGenerator.prepare()
        notificationGenerator.notificationOccurred(type)
    }
}
