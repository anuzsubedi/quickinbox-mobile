import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var session: AppSession
    @State private var appLock = AppLockController()

    init() {
        let mailboxCache = MailboxCache()
        _session = State(initialValue: AppSession(mailboxCache: mailboxCache))
    }

    var body: some View {
        appContent
            .accessibilityHidden(appLock.isLocked)
            .allowsHitTesting(!appLock.isLocked)
            .environment(appLock)
            .overlay {
                if appLock.isLocked {
                    AppLockView(controller: appLock)
                        .transition(reduceMotion ? .identity : .opacity)
                }
            }
            .task { await session.bootstrapIfNeeded() }
            .task { await appLock.unlockIfNeeded() }
            .onChange(of: scenePhase) { _, phase in
                appLock.handleScenePhase(phase)
            }
    }

    @ViewBuilder
    private var appContent: some View {
        Group {
            switch session.phase {
            case .booting:
                LaunchView()

            case .onboarding(let message):
                OnboardingContainer(
                    api: session.api,
                    credentialStore: session.credentialStore,
                    message: message,
                    onAuthenticated: session.didAuthenticate
                )

            case .authenticated(let user):
                AuthenticatedRootView(
                    api: session.api,
                    mailboxCache: session.mailboxCache,
                    currentUser: user,
                    onDisconnected: session.didDisconnect
                )
                .id(user.id)

            case .restoreFailed(let message):
                SessionRestoreErrorView(
                    message: message,
                    retry: { Task { await session.retryRestore() } },
                    removeLocalData: { Task { await session.removeLocalData() } }
                )
            }
        }
    }
}

private struct LaunchView: View {
    var body: some View {
        VStack(spacing: QuickMailDesign.Spacing.xxl) {
            QuickMailMark(size: .title)
                .foregroundStyle(.white)
                .frame(width: 72, height: 72)
                .background(QuickMailDesign.Palette.sage, in: RoundedRectangle(cornerRadius: 20))

            VStack(spacing: QuickMailDesign.Spacing.sm) {
                Text("QuickMail")
                    .font(.title.bold())
                    .foregroundStyle(.white)
                Text("Opening your mailbox…")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.72))
            }

            ProgressView()
                .tint(.white)
                .controlSize(.small)
                .accessibilityLabel("Opening QuickMail")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(QuickMailDesign.Palette.signalInk)
    }
}

private struct OnboardingContainer: View {
    let api: QuickMailAPI
    let credentialStore: CredentialStore
    let message: String?
    let onAuthenticated: @MainActor (Credential, User) -> Void

    var body: some View {
        VStack(spacing: 0) {
            if let message {
                Label(message, systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    .background(.bar)
            }

            OnboardingView(
                api: api,
                credentialStore: credentialStore,
                onAuthenticated: onAuthenticated
            )
        }
    }
}

private struct SessionRestoreErrorView: View {
    let message: String
    let retry: () -> Void
    let removeLocalData: () -> Void
    @State private var isRemovalConfirmationPresented = false

    var body: some View {
        ContentUnavailableView {
            Label("Session Couldn’t Be Verified", systemImage: "wifi.exclamationmark")
        } description: {
            Text(message)
        } actions: {
            Button("Try Again", action: retry)
                .buttonStyle(.borderedProminent)
            Button("Remove Local Data…", role: .destructive) {
                isRemovalConfirmationPresented = true
            }
                .buttonStyle(.bordered)
        }
        .confirmationDialog(
            "Remove QuickMail data from this iPhone?",
            isPresented: $isRemovalConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Remove Data", role: .destructive, action: removeLocalData)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your saved session and cached mail will be removed. If the server is unavailable, you may still need to revoke this iPhone on QuickMail on the web.")
        }
    }
}
