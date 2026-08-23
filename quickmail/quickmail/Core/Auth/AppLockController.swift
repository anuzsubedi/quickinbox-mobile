import LocalAuthentication
import Observation
import SwiftUI

@MainActor
@Observable
final class AppLockController {
    private static let enabledKey = "quickmail.biometricLockEnabled"

    private(set) var isEnabled: Bool
    private(set) var isLocked: Bool
    private(set) var isAvailable = false
    private(set) var biometryName = "Biometric Lock"
    private(set) var isAuthenticating = false
    var errorMessage: String?

    init() {
        let enabled = UserDefaults.standard.bool(forKey: Self.enabledKey)
        isEnabled = enabled
        isLocked = enabled
        refreshAvailability()
    }

    func refreshAvailability() {
        let context = LAContext()
        var error: NSError?
        isAvailable = context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            error: &error
        )
        switch context.biometryType {
        case .faceID: biometryName = "Face ID"
        case .touchID: biometryName = "Touch ID"
        case .opticID: biometryName = "Optic ID"
        case .none: biometryName = "Biometric Lock"
        @unknown default: biometryName = "Biometric Lock"
        }

        if !isAvailable, isEnabled {
            // Keep the preference so it resumes when biometrics become available,
            // but never expose content until the device can authenticate again.
            isLocked = true
        }
    }

    func setEnabled(_ enabled: Bool) async {
        errorMessage = nil
        if !enabled {
            isEnabled = false
            isLocked = false
            UserDefaults.standard.removeObject(forKey: Self.enabledKey)
            return
        }

        refreshAvailability()
        guard isAvailable else {
            errorMessage = "Set up biometrics in Settings before enabling QuickMail Lock."
            AppFeedback.error()
            return
        }

        guard await authenticate(reason: "Enable biometric protection for QuickMail.") else {
            return
        }
        isEnabled = true
        isLocked = false
        UserDefaults.standard.set(true, forKey: Self.enabledKey)
        AppFeedback.success()
    }

    func unlockIfNeeded() async {
        guard isEnabled, isLocked, !isAuthenticating else { return }
        refreshAvailability()
        guard isAvailable else {
            errorMessage = "Biometric authentication is unavailable. Check your device settings and try again."
            return
        }

        if await authenticate(reason: "Unlock QuickMail to view your mail.") {
            isLocked = false
            AppFeedback.success()
        }
    }

    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .inactive:
            if isEnabled, !isAuthenticating { isLocked = true }
        case .background:
            if isEnabled { isLocked = true }
        case .active:
            if isEnabled, isLocked {
                Task { await unlockIfNeeded() }
            }
        @unknown default:
            break
        }
    }

    private func authenticate(reason: String) async -> Bool {
        guard !isAuthenticating else { return false }
        isAuthenticating = true
        errorMessage = nil
        defer { isAuthenticating = false }

        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        do {
            return try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
        } catch let error as LAError {
            switch error.code {
            case .userCancel, .systemCancel, .appCancel:
                break
            case .biometryNotAvailable, .biometryNotEnrolled:
                errorMessage = "Biometric authentication is not set up on this device."
            case .biometryLockout:
                errorMessage = "Biometrics are temporarily locked. Unlock the device and try again."
            default:
                errorMessage = "QuickMail couldn’t verify your identity. Try again."
            }
            AppFeedback.error()
            return false
        } catch {
            errorMessage = "QuickMail couldn’t verify your identity. Try again."
            AppFeedback.error()
            return false
        }
    }
}

struct AppLockView: View {
    let controller: AppLockController

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
                Text("QuickMail Locked")
                    .font(.title2.bold())
                Text("Use \(controller.biometryName) to view your mail.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                if let errorMessage = controller.errorMessage {
                    Text(errorMessage)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                Button {
                    Task { await controller.unlockIfNeeded() }
                } label: {
                    if controller.isAuthenticating {
                        ProgressView()
                            .frame(minWidth: 90)
                    } else {
                        Label("Unlock", systemImage: "faceid")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(controller.isAuthenticating || !controller.isAvailable)
            }
            .frame(maxWidth: 420)
            .padding(32)
        }
        .accessibilityAddTraits(.isModal)
    }
}
