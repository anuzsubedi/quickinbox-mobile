import SwiftUI

struct ErrorStateView: View {
    let title: String
    let message: String
    var retryTitle = "Try Again"
    var retry: (() -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(.orange)
                .frame(width: 72, height: 72)
                .background(QuickMailDesign.Palette.fill, in: Circle())
            Text(title)
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(QuickMailDesign.Palette.secondaryText)
                .multilineTextAlignment(.center)
            if let retry {
                Button {
                    retry()
                } label: {
                    Text(retryTitle).frame(minWidth: 120)
                }
                    .quickMailProminentButtonStyle()
            }
        }
        .padding(24)
        .quickMailCard()
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(QuickMailDesign.Palette.paperGrouped)
    }
}
