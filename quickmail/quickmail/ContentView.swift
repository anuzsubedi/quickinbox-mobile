import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var session: AppSession
    @State private var appLock = AppLockController()
    @AppStorage(AppPreferences.appThemeID) private var appThemeID = AppThemeRegistry.defaultThemeID

    init() {
        let mailboxCache = MailboxCache()
        _session = State(initialValue: AppSession(mailboxCache: mailboxCache))
    }

    var body: some View {
        appContent
            .quickMailStyleRoot()
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
            .preferredColorScheme(selectedTheme.preferredColorScheme)
            .environment(\.appTheme, selectedTheme)
            .tint(QuickMailDesign.Palette.interactiveTint)
    }

    private var selectedTheme: AppTheme {
        AppThemeRegistry.theme(id: appThemeID)
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsProgress = false

    var body: some View {
        VStack(spacing: QuickMailDesign.Spacing.xl) {
            QuickMailMark(size: .system(size: 34, weight: .semibold))
                .foregroundStyle(QuickMailDesign.Palette.interactiveTint)
                .frame(width: 84, height: 84)
                .background(QuickMailDesign.Palette.fill, in: Circle())
                .overlay {
                    Circle()
                        .stroke(QuickMailDesign.Palette.separator.opacity(0.55), lineWidth: 0.5)
                }

            Text("QuickMail")
                .font(.title.bold())
                .foregroundStyle(QuickMailDesign.Palette.primaryText)

            ProgressView()
                .controlSize(.small)
                .tint(QuickMailDesign.Palette.interactiveTint)
                .opacity(showsProgress ? 1 : 0)
                .accessibilityHidden(!showsProgress)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(QuickMailDesign.Palette.paper)
        .accessibilityLabel("Opening QuickMail")
        .task {
            do {
                try await Task.sleep(for: .milliseconds(800))
            } catch {
                return
            }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.15)) {
                showsProgress = true
            }
        }
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
                    .font(.quickMailBody(16, relativeTo: .callout))
                    .foregroundStyle(QuickMailDesign.Palette.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    .quickMailBarSurface()
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
                .quickMailProminentButtonStyle()
            Button("Remove Local Data…", role: .destructive) {
                isRemovalConfirmationPresented = true
            }
                .quickMailDestructiveButtonStyle()
        }
        .quickMailPageSurface()
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
