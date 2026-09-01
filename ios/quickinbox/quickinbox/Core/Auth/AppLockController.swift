import LocalAuthentication
import Observation
import SwiftUI

@MainActor
@Observable
final class AppLockController {
    private static let enabledKey = "quickinbox.biometricLockEnabled"

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
            .deviceOwnerAuthentication,
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
            errorMessage = "Set up a device passcode before enabling QuickInbox Lock."
            AppFeedback.error()
            return
        }

        guard await authenticate(reason: "Enable biometric protection for QuickInbox.") else {
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
            errorMessage = "Device authentication is unavailable. Check Settings and try again."
            return
        }

        if await authenticate(reason: "Unlock QuickInbox to view your mail.") {
            isLocked = false
            AppFeedback.success()
        }
    }

    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .inactive:
            // Hide mail when leaving the app (Control Center, app switcher), but
            // never interrupt an in-flight unlock — that left a blank lock frame
            // under Xcode / Face ID.
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
        // Set before evaluatePolicy suspends so an .inactive transition from the
        // system auth sheet cannot re-lock mid-prompt.
        isAuthenticating = true
        errorMessage = nil
        defer { isAuthenticating = false }

        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        do {
            return try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            )
        } catch let error as LAError {
            switch error.code {
            case .userCancel, .systemCancel, .appCancel:
                break
            case .biometryNotAvailable, .biometryNotEnrolled:
                errorMessage = "Use your device passcode to unlock QuickInbox."
            case .biometryLockout:
                errorMessage = "Biometrics are temporarily locked. Unlock the device and try again."
            default:
                errorMessage = "QuickInbox couldn’t verify your identity. Try again."
            }
            AppFeedback.error()
            return false
        } catch {
            errorMessage = "QuickInbox couldn’t verify your identity. Try again."
            AppFeedback.error()
            return false
        }
    }
}

struct AppLockView: View {
    let controller: AppLockController

    var body: some View {
        ZStack {
            QuickInboxDesign.Palette.paper.ignoresSafeArea()

            VStack(spacing: 18) {
                QuickInboxMark(size: .largeTitle)
                    .frame(width: 56, height: 56)
                Text("QuickInbox Locked")
                    .font(.title2.weight(.semibold))
                Text("Use \(controller.biometryName) or your device passcode to view your mail.")
                    .foregroundStyle(QuickInboxDesign.Palette.secondaryText)
                    .multilineTextAlignment(.center)

                if let errorMessage = controller.errorMessage {
                    Text(errorMessage)
                        .font(.quickInboxBody(16, relativeTo: .callout))
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
                        Label("Unlock", systemImage: "lock.open.fill")
                    }
                }
                .quickInboxProminentButtonStyle()
                .controlSize(.large)
                .disabled(controller.isAuthenticating || !controller.isAvailable)
            }
            .frame(maxWidth: 420)
            .padding(32)
        }
        .accessibilityAddTraits(.isModal)
    }
}
