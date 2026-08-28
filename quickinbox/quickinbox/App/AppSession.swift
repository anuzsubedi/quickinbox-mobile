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
    private(set) var phase: Phase = .booting

    private var hasBootstrapped = false
    private var restoreGeneration = 0

    init(
        api: QuickInboxAPI = QuickInboxAPI(),
        credentialStore: CredentialStore = CredentialStore(),
        mailboxCache: MailboxCache
    ) {
        self.api = api
        self.credentialStore = credentialStore
        self.mailboxCache = mailboxCache
    }

    func bootstrapIfNeeded() async {
        guard !hasBootstrapped else { return }
        hasBootstrapped = true
        await restoreSession()
    }

    func retryRestore() async {
        await restoreSession()
    }

    func didAuthenticate(credential: Credential, user: User) {
        restoreGeneration += 1
        cache(user)
        phase = .authenticated(user)

        // Onboarding installs and saves the credential before invoking this callback.
        // Reinstalling here makes the session boundary explicit for alternate callers.
        Task { await api.install(credential) }
    }

    func didDisconnect(message: String?) {
        restoreGeneration += 1
        clearCachedUser()
        phase = .onboarding(message: message)
        mailboxCache.clearAll()
        Task { await api.clearCredential() }
    }

    func removeLocalData() async {
        restoreGeneration += 1
        clearCachedUser()
        try? await credentialStore.delete()
        await api.clearCredential()
        mailboxCache.clearAll()
        phase = .onboarding(message: nil)
    }

    private func restoreSession() async {
        restoreGeneration += 1
        let generation = restoreGeneration
        phase = .booting

        do {
            guard let credential = try await credentialStore.load() else {
                guard generation == restoreGeneration else { return }
                await api.clearCredential()
                phase = .onboarding(message: nil)
                return
            }

            guard !credential.isExpired else {
                clearCachedUser()
                try? await credentialStore.delete()
                await api.clearCredential()
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
            }

            let user = try await api.currentUser()
            cache(user)
            if credential.cachedUser != user {
                try? await credentialStore.save(credential.caching(user: user))
            }
            guard generation == restoreGeneration else { return }
            phase = .authenticated(user)
        } catch APIError.unauthorized {
            clearCachedUser()
            try? await credentialStore.delete()
            await api.clearCredential()
            guard generation == restoreGeneration else { return }
            phase = .onboarding(message: "Your saved session is no longer valid. Connect this device again.")
        } catch CredentialStoreError.corruptCredential {
            clearCachedUser()
            await api.clearCredential()
            guard generation == restoreGeneration else { return }
            phase = .onboarding(message: "The saved session was invalid and has been removed.")
        } catch APIError.transport(_) {
            guard generation == restoreGeneration else { return }
            let savedCredential = try? await credentialStore.load()
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
}
