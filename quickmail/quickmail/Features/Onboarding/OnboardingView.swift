import SwiftUI

struct OnboardingView: View {
    private let api: QuickMailAPI
    private let credentialStore: CredentialStore
    private let onAuthenticated: @MainActor (Credential, User) -> Void

    @State private var serverOrigin = ""
    @State private var pairingCode = ""
    @State private var isScannerPresented = false
    @State private var isConnecting = false
    @State private var errorMessage: String?
    @State private var pendingScannedPayload: ValidatedPairingPayload?
    @State private var showsScannedOriginConfirmation = false
    @FocusState private var focusedField: Field?

    init(
        api: QuickMailAPI,
        credentialStore: CredentialStore,
        onAuthenticated: @escaping @MainActor (Credential, User) -> Void
    ) {
        self.api = api
        self.credentialStore = credentialStore
        self.onAuthenticated = onAuthenticated
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    introduction
                    connectionPanel
                    privacyNote
                }
                .frame(maxWidth: 560)
                .padding(.horizontal, 20)
                .padding(.top, 36)
                .padding(.bottom, 28)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Connect QuickMail")
            .navigationBarTitleDisplayMode(.inline)
        }
        .interactiveDismissDisabled(isConnecting)
        .sheet(isPresented: $isScannerPresented) {
            QRScannerView(onScan: receiveScannedValue)
        }
        .alert("Check QuickMail Server", isPresented: $showsScannedOriginConfirmation) {
            Button("Cancel", role: .cancel) {
                pendingScannedPayload = nil
            }
            Button("Connect") {
                guard let payload = pendingScannedPayload else { return }
                pendingScannedPayload = nil
                serverOrigin = payload.origin.absoluteString
                pairingCode = payload.code
                beginConnection(with: payload)
            }
        } message: {
            Text(scannedOriginConfirmationMessage)
        }
    }

    private var introduction: some View {
        VStack(spacing: 16) {
            QuickMailMark(size: .largeTitle)
                .frame(width: 76, height: 76)
                .background(Color.accentColor.opacity(0.1), in: Circle())

            VStack(spacing: 7) {
                Text("Your mailbox. Your server.")
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                Text("Pair this device from QuickMail on the web. The connection belongs to the server you choose.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var connectionPanel: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Connect securely")
                    .font(.title3.weight(.semibold))
                Text("In the web app, open Settings and choose Connect mobile app.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            PlatformPrimaryActionButton {
                focusedField = nil
                errorMessage = nil
                isScannerPresented = true
            } label: {
                Label("Scan Pairing Code", systemImage: "qrcode.viewfinder")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .controlSize(.large)
            .disabled(isConnecting)

            HStack(spacing: 12) {
                Divider()
                Text("or enter it manually")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize()
                Divider()
            }

            VStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 7) {
                    Label("Server", systemImage: "server.rack")
                        .font(.subheadline.weight(.semibold))
                    TextField("https://mail.example.com", text: $serverOrigin)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.next)
                        .focused($focusedField, equals: .server)
                        .onSubmit { focusedField = .code }
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 7) {
                    Label("Pairing code", systemImage: "number")
                        .font(.subheadline.weight(.semibold))
                    TextField("22-character code", text: $pairingCode)
                        .textContentType(.oneTimeCode)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .fontDesign(.monospaced)
                        .submitLabel(.go)
                        .focused($focusedField, equals: .code)
                        .onSubmit(connectManually)
                        .textFieldStyle(.roundedBorder)
                }
            }

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .combine)
            }

            Button(action: connectManually) {
                HStack {
                    if isConnecting {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text(isConnecting ? "Connecting…" : "Connect Manually")
                }
                .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(isConnecting || serverOrigin.isEmpty || pairingCode.isEmpty)
        }
        .padding(20)
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: QuickMailDesign.compactCornerRadius, style: .continuous)
        )
    }

    private var privacyNote: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lock.shield.fill")
                .foregroundStyle(.tint)
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text("Private by design")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text("The code works once and expires quickly. Your session is stored securely in Keychain on this device.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
        .accessibilityElement(children: .combine)
    }

    private var scannedOriginConfirmationMessage: String {
        guard let payload = pendingScannedPayload else { return "Confirm the server before connecting." }
        let host = payload.origin.host(percentEncoded: false) ?? payload.origin.host ?? payload.origin.absoluteString
        return "Only continue if \(host) is the QuickMail server shown in your browser."
    }

    private func receiveScannedValue(_ value: String) {
        do {
            let payload = try PairingPayloadValidator.validate(scannedValue: value)
            errorMessage = nil
            pendingScannedPayload = payload
            showsScannedOriginConfirmation = true
        } catch {
            errorMessage = userFacingMessage(for: error)
        }
    }

    private func connectManually() {
        focusedField = nil
        do {
            let payload = try PairingPayloadValidator.validate(origin: serverOrigin, code: pairingCode)
            serverOrigin = payload.origin.absoluteString
            pairingCode = payload.code
            beginConnection(with: payload)
        } catch {
            errorMessage = userFacingMessage(for: error)
        }
    }

    private func beginConnection(with payload: ValidatedPairingPayload) {
        guard !isConnecting else { return }
        isConnecting = true
        errorMessage = nil

        Task {
            var installedCredential = false
            do {
                let credential = try await api.pair(
                    origin: payload.origin.absoluteString,
                    code: payload.code,
                    deviceName: "QuickMail for iOS"
                )
                await api.install(credential)
                installedCredential = true

                let user = try await api.currentUser()
                let restorableCredential = credential.caching(user: user)
                await api.install(restorableCredential)
                try await credentialStore.save(restorableCredential)

                isConnecting = false
                AppFeedback.success()
                onAuthenticated(restorableCredential, user)
            } catch {
                if installedCredential {
                    try? await api.logout(credentialStore: credentialStore)
                    await api.clearCredential()
                }
                isConnecting = false
                errorMessage = userFacingMessage(for: error)
            }
        }
    }

    private func userFacingMessage(for error: Error) -> String {
        if let localized = error as? LocalizedError,
           let message = localized.errorDescription,
           !message.isEmpty {
            return message
        }
        return "QuickMail couldn’t complete pairing. Try again."
    }

    private enum Field: Hashable {
        case server
        case code
    }
}
