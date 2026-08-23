import UIKit

nonisolated enum AppFeedback {
    @MainActor
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    @MainActor
    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    @MainActor
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
