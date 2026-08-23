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

    let api: QuickMailAPI
    let credentialStore: CredentialStore
    private(set) var phase: Phase = .booting

    private var hasBootstrapped = false
    private var restoreGeneration = 0

    init(
        api: QuickMailAPI = QuickMailAPI(),
        credentialStore: CredentialStore = CredentialStore()
    ) {
        self.api = api
        self.credentialStore = credentialStore
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
        phase = .authenticated(user)

        // Onboarding installs and saves the credential before invoking this callback.
        // Reinstalling here makes the session boundary explicit for alternate callers.
        Task { await api.install(credential) }
    }

    func didDisconnect() {
        restoreGeneration += 1
        phase = .onboarding(message: nil)
        Task { await api.clearCredential() }
    }

    func removeLocalData() async {
        restoreGeneration += 1
        try? await credentialStore.delete()
        await api.clearCredential()
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
                try? await credentialStore.delete()
                await api.clearCredential()
                guard generation == restoreGeneration else { return }
                phase = .onboarding(message: "Your saved session expired. Connect this device again.")
                return
            }

            await api.install(credential)
            let user = try await api.currentUser()
            guard generation == restoreGeneration else { return }
            phase = .authenticated(user)
        } catch APIError.unauthorized {
            try? await credentialStore.delete()
            await api.clearCredential()
            guard generation == restoreGeneration else { return }
            phase = .onboarding(message: "Your saved session is no longer valid. Connect this device again.")
        } catch CredentialStoreError.corruptCredential {
            await api.clearCredential()
            guard generation == restoreGeneration else { return }
            phase = .onboarding(message: "The saved session was invalid and has been removed.")
        } catch {
            guard generation == restoreGeneration else { return }
            phase = .restoreFailed(message: userFacingMessage(for: error))
        }
    }

    private func userFacingMessage(for error: Error) -> String {
        if let localized = error as? LocalizedError,
           let description = localized.errorDescription,
           !description.isEmpty {
            return description
        }
        return "QuickMail couldn’t reach your server. Check your connection and try again."
    }
}
