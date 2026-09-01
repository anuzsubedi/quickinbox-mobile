import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var session: AppSession
    @State private var appLock = AppLockController()
    @AppStorage(AppPreferences.appThemeID) private var appThemeID = AppThemeRegistry.defaultThemeID

    init() {
        let mailboxCache = MailboxCache()
        let threadCache = ThreadDetailCache()
        _session = State(
            initialValue: AppSession(mailboxCache: mailboxCache, threadCache: threadCache)
        )
    }

    var body: some View {
        // Always paint paper first so the system launch screen never falls through
        // to an unstyled black window while session restore or Face ID starts.
        ZStack {
            QuickInboxDesign.Palette.paper.ignoresSafeArea()

            if appLock.isLocked {
                // Skip mounting the mailbox tree while locked — building it under the
                // lock overlay delayed the first meaningful frame on relaunch.
                AppLockView(controller: appLock)
            } else {
                appContent
            }
        }
        .quickInboxStyleRoot()
        .environment(appLock)
        .task {
            if !appLock.isLocked {
                await session.bootstrapIfNeeded()
            }
        }
        .task { await appLock.unlockIfNeeded() }
        .onChange(of: appLock.isLocked) { _, locked in
            if !locked {
                Task { await session.bootstrapIfNeeded() }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            appLock.handleScenePhase(phase)
        }
        .preferredColorScheme(selectedTheme.preferredColorScheme)
        .environment(\.appTheme, selectedTheme)
        .tint(QuickInboxDesign.Palette.interactiveTint)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: appLock.isLocked)
    }

    private var selectedTheme: AppTheme {
        AppThemeRegistry.theme(id: appThemeID)
            .applying(AppTintRegistry.tint(id: AppTintRegistry.defaultTintID))
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
                    threadCache: session.threadCache,
                    currentUser: user,
                    needsSignOut: session.needsSignOut,
                    onSignOut: session.signOut,
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
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            QuickInboxDesign.Palette.paper
                .ignoresSafeArea()

            if colorScheme == .light {
                Circle()
                    .fill(QuickInboxDesign.Palette.interactiveTint.opacity(0.09))
                    .frame(width: 320, height: 320)
                    .blur(radius: 72)
                    .offset(y: -115)
                    .accessibilityHidden(true)
            }

            VStack(spacing: 0) {
                Image("QuickInboxAppIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 132, height: 132)
                    .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .strokeBorder(.white.opacity(colorScheme == .dark ? 0.12 : 0.2), lineWidth: 0.5)
                    }
                    .shadow(
                        color: Color.black.opacity(colorScheme == .dark ? 0.38 : 0.18),
                        radius: 24,
                        y: 12
                    )
                    .accessibilityHidden(true)

                Text("QuickInbox")
                    .font(.largeTitle.bold())
                    .foregroundStyle(QuickInboxDesign.Palette.primaryText)
                    .padding(.top, QuickInboxDesign.Spacing.xxxl)

                Text("Your inbox, ready when you are.")
                    .font(.subheadline)
                    .foregroundStyle(QuickInboxDesign.Palette.secondaryText)
                    .padding(.top, QuickInboxDesign.Spacing.sm)

                HStack(spacing: QuickInboxDesign.Spacing.sm) {
                    ProgressView()
                        .controlSize(.small)
                        .tint(QuickInboxDesign.Palette.interactiveTint)

                    Text("Opening your inbox")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(QuickInboxDesign.Palette.secondaryText)
                }
                .padding(.horizontal, QuickInboxDesign.Spacing.md)
                .padding(.vertical, 10)
                .background(QuickInboxDesign.Palette.fill, in: Capsule())
                .overlay {
                    Capsule()
                        .strokeBorder(QuickInboxDesign.Palette.separator.opacity(0.45), lineWidth: 0.5)
                }
                .padding(.top, QuickInboxDesign.Spacing.xxl)
            }
            .padding(QuickInboxDesign.Spacing.xxxl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("QuickInbox. Opening your inbox.")
    }
}

private struct OnboardingContainer: View {
    let api: QuickInboxAPI
    let credentialStore: CredentialStore
    let message: String?
    let onAuthenticated: @MainActor (Credential, User) -> Void

    var body: some View {
        VStack(spacing: 0) {
            if let message {
                Label(message, systemImage: "info.circle")
                    .font(.quickInboxBody(16, relativeTo: .callout))
                    .foregroundStyle(QuickInboxDesign.Palette.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    .quickInboxBarSurface()
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
        EmptyStateView(
            systemImage: "wifi.exclamationmark",
            title: "Session Couldn’t Be Verified",
            message: message,
            tone: .warning,
            layout: .page,
            actions: [
                EmptyStateAction("Try Again", isProminent: true, handler: retry),
                EmptyStateAction("Remove Local Data…", role: .destructive) {
                    isRemovalConfirmationPresented = true
                }
            ]
        )
        .quickInboxPageSurface()
        .confirmationDialog(
            "Remove QuickInbox data from this iPhone?",
            isPresented: $isRemovalConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Remove Data", role: .destructive, action: removeLocalData)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your saved session and cached mail will be removed. If the server is unavailable, you may still need to revoke this iPhone on QuickInbox on the web.")
        }
    }
}
