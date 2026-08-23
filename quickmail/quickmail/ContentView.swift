import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var session: AppSession
    @State private var appLock = AppLockController()

    init() {
        let mailboxCache = MailboxCache()
        _session = State(initialValue: AppSession(mailboxCache: mailboxCache))
    }

    var body: some View {
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
        .environment(appLock)
        .overlay {
            if appLock.isLocked {
                AppLockView(controller: appLock)
            }
        }
        .task { await session.bootstrapIfNeeded() }
        .task { await appLock.unlockIfNeeded() }
        .onChange(of: scenePhase) { _, phase in
            appLock.handleScenePhase(phase)
        }
    }
}

private struct LaunchView: View {
    var body: some View {
        VStack(spacing: 20) {
            QuickMailMark(size: .largeTitle)
                .frame(width: 72, height: 72)
                .background(Color.accentColor.opacity(0.1), in: Circle())

            VStack(spacing: 6) {
                Text("QuickMail")
                    .font(.title2.bold())
                Text("Opening your mailbox…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ProgressView()
                .controlSize(.small)
                .accessibilityLabel("Opening QuickMail")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemGroupedBackground))
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

    var body: some View {
        ContentUnavailableView {
            Label("Couldn’t Verify Session", systemImage: "wifi.exclamationmark")
        } description: {
            Text(message)
        } actions: {
            Button("Try Again", action: retry)
                .buttonStyle(.borderedProminent)
            Button("Connect to a Different Server", role: .destructive, action: removeLocalData)
                .buttonStyle(.bordered)
        }
    }
}
