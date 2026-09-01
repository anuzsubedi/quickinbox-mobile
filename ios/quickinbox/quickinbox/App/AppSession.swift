import Foundation
import Observation

@MainActor
@Observable
final class AppSession {
    enum Phase {
        case booting
        case onboarding(message: String?)
        case authenticated(User)
        case restoreFailed(message: String)
    }

    let api: QuickInboxAPI
    let credentialStore: CredentialStore
    let mailboxCache: MailboxCache
    let threadCache: ThreadDetailCache
    private(set) var phase: Phase = .booting
    /// Set when the server revokes this device mid-session. Stay in the mailbox UI
    /// and show Sign Out on the session banner instead of error dialogs.
    private(set) var needsSignOut = false

    private var hasBootstrapped = false
    private var restoreGeneration = 0

    init(
        api: QuickInboxAPI = QuickInboxAPI(),
        credentialStore: CredentialStore = CredentialStore(),
        mailboxCache: MailboxCache,
        threadCache: ThreadDetailCache
    ) {
        self.api = api
        self.credentialStore = credentialStore
        self.mailboxCache = mailboxCache
        self.threadCache = threadCache
        Task { await self.installUnauthorizedHandler() }
    }

    private func installUnauthorizedHandler() async {
        await api.setOnUnauthorized { [weak self] in
            Task { @MainActor in
                self?.handleUnauthorized()
            }
        }
    }

    func bootstrapIfNeeded() async {
        guard !hasBootstrapped else { return }
        hasBootstrapped = true
        // Yield so LaunchView can paint before Keychain work. Doing SecItem on the
        // main thread during ContentView.init leaves a blank system window (often
        // black), especially when relaunching under the Xcode debugger.
        await Task.yield()
        await restoreSession()
    }

    func retryRestore() async {
        await restoreSession()
    }

    func didAuthenticate(credential: Credential, user: User) {
        restoreGeneration += 1
        needsSignOut = false
        cache(user)
        phase = .authenticated(user)

        // Onboarding installs and saves the credential before invoking this callback.
        // Reinstalling here makes the session boundary explicit for alternate callers.
        Task { await api.install(credential) }
    }

    func didDisconnect(message: String?) {
        restoreGeneration += 1
        needsSignOut = false
        clearCachedUser()
        phase = .onboarding(message: message)
        clearMailCaches()
        Task { await api.clearCredential() }
    }

    func removeLocalData() async {
        restoreGeneration += 1
        needsSignOut = false
        clearCachedUser()
        try? credentialStore.delete()
        await api.clearCredential()
        clearMailCaches()
        phase = .onboarding(message: nil)
    }

    /// Clears local session after a mid-session revoke. Does not bounce to onboarding
    /// until the user taps Sign Out.
    func handleUnauthorized() {
        guard case .authenticated = phase, !needsSignOut else { return }
        needsSignOut = true
        try? credentialStore.delete()
        clearMailCaches()
        Task { await api.clearCredential() }
    }

    func signOut() {
        didDisconnect(message: nil)
    }

    private func restoreSession() async {
        restoreGeneration += 1
        let generation = restoreGeneration
        phase = .booting

        do {
            guard let credential = try credentialStore.load() else {
                guard generation == restoreGeneration else { return }
                await api.clearCredential()
                clearMailCaches()
                phase = .onboarding(message: nil)
                return
            }

            guard !credential.isExpired else {
                clearCachedUser()
                try? credentialStore.delete()
                await api.clearCredential()
                clearMailCaches()
                guard generation == restoreGeneration else { return }
                phase = .onboarding(message: "Your saved session expired. Connect this device again.")
                return
            }

            await api.install(credential)

            // A paired account always stores a cached user. Restore that account
            // immediately so launch is never blocked by a network round trip;
            // session validation can finish while the mailbox loads normally.
            if let cachedUser = credential.cachedUser ?? locallyCachedUser() {
                guard generation == restoreGeneration else { return }
                phase = .authenticated(cachedUser)
                await Task.yield()
            }

            let user = try await api.currentUser()
            cache(user)
            if credential.cachedUser != user {
                try? credentialStore.save(credential.caching(user: user))
            }
            guard generation == restoreGeneration else { return }
            phase = .authenticated(user)
        } catch APIError.unauthorized {
            clearCachedUser()
            try? credentialStore.delete()
            await api.clearCredential()
            clearMailCaches()
            guard generation == restoreGeneration else { return }
            phase = .onboarding(message: "Your saved session is no longer valid. Connect this device again.")
        } catch CredentialStoreError.corruptCredential {
            clearCachedUser()
            await api.clearCredential()
            clearMailCaches()
            guard generation == restoreGeneration else { return }
            phase = .onboarding(message: "The saved session was invalid and has been removed.")
        } catch APIError.transport(_) {
            guard generation == restoreGeneration else { return }
            let savedCredential = try? credentialStore.load()
            if let cachedUser = savedCredential?.cachedUser ?? locallyCachedUser() {
                // The cached account may already be visible. Keep it available
                // offline rather than returning to the launch screen.
                if case .booting = phase {
                    phase = .authenticated(cachedUser)
                }
            } else if case .booting = phase {
                phase = .restoreFailed(
                    message: "QuickInbox couldn’t reach your server and this account has not been cached yet."
                )
            }
        } catch {
            guard generation == restoreGeneration else { return }
            if case .booting = phase {
                phase = .restoreFailed(message: userFacingMessage(for: error))
            }
        }
    }

    private func userFacingMessage(for error: Error) -> String {
        if let localized = error as? LocalizedError,
           let description = localized.errorDescription,
           !description.isEmpty {
            return description
        }
        return "QuickInbox couldn’t reach your server. Check your connection and try again."
    }

    private func cache(_ user: User) {
        guard let data = try? JSONEncoder().encode(user) else { return }
        UserDefaults.standard.set(data, forKey: AppPreferences.cachedUser)
    }

    private func locallyCachedUser() -> User? {
        guard let data = UserDefaults.standard.data(forKey: AppPreferences.cachedUser) else {
            return nil
        }
        return try? JSONDecoder().decode(User.self, from: data)
    }

    private func clearCachedUser() {
        UserDefaults.standard.removeObject(forKey: AppPreferences.cachedUser)
    }

    private func clearMailCaches() {
        mailboxCache.clearAll()
        threadCache.clearAll()
    }
}
