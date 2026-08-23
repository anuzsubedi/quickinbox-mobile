import SwiftUI

struct OnboardingView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
    @State private var showsManualPairing = false
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
            ZStack(alignment: .top) {
                onboardingBackground

                ScrollView {
                    VStack(spacing: 0) {
                        brandHeader
                        introduction
                        scanAction
                            .padding(.top, 28)
                        scanInstructions
                            .padding(.top, 14)
                        connectionError
                            .padding(.top, errorMessage == nil ? 0 : 18)
                        manualPairing
                            .padding(.top, 22)
                        privacyNote
                            .padding(.top, 22)
                    }
                    .frame(maxWidth: 520)
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 36)
                    .frame(maxWidth: .infinity)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
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

    private var onboardingBackground: some View {
        QuickMailDesign.Palette.paperGrouped
        .ignoresSafeArea()
    }

    private var brandHeader: some View {
        HStack(spacing: 10) {
            SignalDeskMark()

            Text("QuickMail")
                .font(.headline.weight(.semibold))

            Spacer()

            ViewThatFits(in: .horizontal) {
                Label("Secure pairing", systemImage: "lock.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                Image(systemName: "lock.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Secure pairing")
            }
        }
        .padding(.bottom, 40)
        .accessibilityElement(children: .combine)
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connect to your mailbox")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Text("Scan the pairing code from QuickMail on the web. Your iPhone connects directly to the server you choose.")
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var scanAction: some View {
        PlatformPrimaryActionButton {
            focusedField = nil
            errorMessage = nil
            isScannerPresented = true
        } label: {
            HStack(spacing: 10) {
                if isConnecting {
                    ProgressView()
                        .controlSize(.small)
                        .tint(Color(uiColor: .systemBackground))
                } else {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.title3.weight(.semibold))
                }

                Text(isConnecting ? "Connecting securely…" : "Scan Pairing Code")
                    .font(.headline)

                Spacer(minLength: 8)

                if !isConnecting {
                    Image(systemName: "arrow.up.right")
                        .font(.subheadline.weight(.semibold))
                        .accessibilityHidden(true)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .padding(.horizontal, 4)
        }
        .controlSize(.large)
        .disabled(isConnecting)
    }

    private var scanInstructions: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: "safari")
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            Text("On the web: **Settings**  →  **Connect mobile app**")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var connectionError: some View {
        if let errorMessage {
            Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                .font(.callout)
                .foregroundStyle(Color(uiColor: .label))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Color(uiColor: .systemRed).opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color(uiColor: .systemRed).opacity(0.28), lineWidth: 0.5)
                }
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
                .accessibilityElement(children: .combine)
        }
    }

    private var manualPairing: some View {
        DisclosureGroup(isExpanded: manualPairingBinding) {
            VStack(alignment: .leading, spacing: 16) {
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
            .padding(.top, 18)
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text("Enter code manually")
                    .font(.headline)
                Text("Use the server address and pairing code instead.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .tint(.accentColor)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))
        .overlay {
            RoundedRectangle(cornerRadius: 22)
                .strokeBorder(Color(uiColor: .separator).opacity(0.5), lineWidth: 0.5)
        }
    }

    private var manualPairingBinding: Binding<Bool> {
        Binding(
            get: { showsManualPairing },
            set: { isExpanded in
                if reduceMotion {
                    showsManualPairing = isExpanded
                } else {
                    withAnimation(.smooth(duration: 0.28)) {
                        showsManualPairing = isExpanded
                    }
                }
            }
        )
    }

    private var privacyNote: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.shield.fill")
                .foregroundStyle(.tint)
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text("Private by design")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text("The pairing code is used once. Your session is stored securely in Keychain, and QuickMail requires HTTPS.")
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

private struct SignalDeskMark: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.accentColor)

            HStack(spacing: 2) {
                VStack(spacing: 2) {
                    Capsule().frame(width: 7, height: 2)
                    Capsule().frame(width: 10, height: 2)
                }
                .foregroundStyle(Color(uiColor: .systemBackground).opacity(0.72))

                Image(systemName: "paperplane.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(uiColor: .systemBackground))
            }
            .offset(x: 1)
        }
        .frame(width: 34, height: 34)
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color(uiColor: .systemBackground).opacity(0.18), lineWidth: 0.5)
        }
        .accessibilityHidden(true)
    }
}
