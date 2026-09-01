import SwiftUI

struct ErrorStateView: View {
    let title: String
    let message: String
    var retryTitle = "Try Again"
    var retry: (() -> Void)?

    var body: some View {
        EmptyStateView(
            systemImage: "exclamationmark.triangle.fill",
            title: title,
            message: message,
            tone: .warning,
            layout: .card,
            actions: retry.map {
                [EmptyStateAction(retryTitle, isProminent: true, handler: $0)]
            } ?? []
        )
    }
}
