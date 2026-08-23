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
    @State private var hasAppeared = false
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
            ZStack {
                QuickMailDesign.Palette.paperGrouped
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        brand
                        pairingBridge
                            .padding(.top, 44)
                        introduction
                            .padding(.top, 36)
                        webLocation
                            .padding(.top, 24)
                        connectionError
                            .padding(.top, errorMessage == nil ? 0 : 20)
                        securityNote
                            .padding(.top, 28)
                    }
                    .frame(maxWidth: 480)
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 32)
                    .frame(maxWidth: .infinity)
                    .opacity(hasAppeared ? 1 : 0)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                primaryActions
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .interactiveDismissDisabled(isConnecting)
        .task {
            await revealContent()
        }
        .sheet(isPresented: $isScannerPresented) {
            QRScannerView(onScan: receiveScannedValue)
        }
        .sheet(isPresented: $showsManualPairing) {
            manualPairingSheet
        }
        .alert("Check QuickMail Server", isPresented: $showsScannedOriginConfirmation) {
            Button("Cancel", role: .cancel) {
                pendingScannedPayload = nil
            }
            Button("Connect") {
                guard let payload = pendingScannedPayload else { return }
                AppFeedback.play(.moveConfirmed)
                pendingScannedPayload = nil
                serverOrigin = payload.origin.absoluteString
                pairingCode = payload.code
                beginConnection(with: payload)
            }
        } message: {
            Text(scannedOriginConfirmationMessage)
        }
    }

    private var brand: some View {
        HStack(spacing: 12) {
            Image("LaunchIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

            Text("QuickMail")
                .font(.title3.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .accessibilityElement(children: .combine)
    }

    private var pairingBridge: some View {
        HStack(alignment: .top, spacing: 14) {
            pairingEndpoint(symbol: "macbook", title: "QuickMail web")

            VStack(spacing: 7) {
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(uiColor: .separator))
                        .frame(height: 2)

                    Capsule()
                        .fill(Color.accentColor)
                        .frame(height: 2)
                        .scaleEffect(x: hasAppeared ? 1 : 0, anchor: .leading)
                }
                .frame(width: 76, height: 26)
                .overlay {
                    Image(systemName: "lock.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(6)
                        .background(QuickMailDesign.Palette.paperGrouped, in: Circle())
                        .opacity(hasAppeared ? 1 : 0)
                }

                Text("HTTPS")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 13)
            .accessibilityHidden(true)

            pairingEndpoint(symbol: "iphone.gen3", title: "This iPhone")
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Secure connection from QuickMail on the web to this iPhone using HTTPS")
    }

    private func pairingEndpoint(symbol: String, title: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.title.weight(.medium))
                .foregroundStyle(.primary)
                .frame(width: 58, height: 58)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: Circle())

            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: 100)
    }

    private var introduction: some View {
        VStack(spacing: 10) {
            Text("Pair your iPhone")
                .font(.largeTitle.weight(.bold))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text("Scan the code shown in QuickMail on the web.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }

    private var webLocation: some View {
        Label {
            Text("Settings  ›  Connect mobile app")
                .font(.subheadline.weight(.medium))
        } icon: {
            Image(systemName: "safari.fill")
                .foregroundStyle(.tint)
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("On the web, open Settings, then Connect mobile app")
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

    private var securityNote: some View {
        Label("One-time code · Saved in Keychain", systemImage: "lock.shield.fill")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
    }

    private var primaryActions: some View {
        VStack(spacing: 4) {
            PlatformPrimaryActionButton {
                AppFeedback.play(.moveConfirmed)
                focusedField = nil
                errorMessage = nil
                isScannerPresented = true
            } label: {
                HStack(spacing: 10) {
                    if isConnecting {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    } else {
                        Image(systemName: "qrcode.viewfinder")
                            .font(.title3.weight(.semibold))
                    }

                    Text(isConnecting ? "Connecting…" : "Scan Pairing Code")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity, minHeight: 44)
            }
            .disabled(isConnecting)

            Button {
                AppFeedback.selection()
                errorMessage = nil
                showsManualPairing = true
            } label: {
                Text("Enter Code Manually")
                    .font(.subheadline.weight(.semibold))
                    .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.primary)
            .disabled(isConnecting)
        }
        .frame(maxWidth: 480)
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity)
        .background(.bar)
    }

    private var manualPairingSheet: some View {
        NavigationStack {
            Form {
                Section("Server") {
                    TextField("https://mail.example.com", text: $serverOrigin)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.next)
                        .focused($focusedField, equals: .server)
                        .onSubmit { focusedField = .code }
                }

                Section {
                    TextField("22-character code", text: $pairingCode)
                        .textContentType(.oneTimeCode)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .fontDesign(.monospaced)
                        .submitLabel(.go)
                        .focused($focusedField, equals: .code)
                        .onSubmit(connectManually)
                } header: {
                    Text("Pairing Code")
                } footer: {
                    Text("Find both values in QuickMail on the web.")
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                            .font(.callout)
                            .foregroundStyle(Color(uiColor: .systemRed))
                    }
                }
            }
            .navigationTitle("Enter Pairing Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        focusedField = nil
                        showsManualPairing = false
                    }
                    .disabled(isConnecting)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                PlatformPrimaryActionButton(action: connectManually) {
                    HStack(spacing: 10) {
                        if isConnecting {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.white)
                        }
                        Text(isConnecting ? "Connecting…" : "Connect")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                .disabled(isConnecting || serverOrigin.isEmpty || pairingCode.isEmpty)
                .padding(16)
                .background(.bar)
            }
            .interactiveDismissDisabled(isConnecting)
        }
    }

    private var scannedOriginConfirmationMessage: String {
        guard let payload = pendingScannedPayload else { return "Confirm the server before connecting." }
        let host = payload.origin.host(percentEncoded: false) ?? payload.origin.host ?? payload.origin.absoluteString
        return "Only continue if \(host) is the QuickMail server shown in your browser."
    }

    private func revealContent() async {
        guard !hasAppeared else { return }
        if reduceMotion {
            hasAppeared = true
        } else {
            withAnimation(.easeOut(duration: 0.6)) {
                hasAppeared = true
            }
        }
    }

    private func receiveScannedValue(_ value: String) {
        do {
            let payload = try PairingPayloadValidator.validate(scannedValue: value)
            errorMessage = nil
            pendingScannedPayload = payload
            showsScannedOriginConfirmation = true
            AppFeedback.selection()
        } catch {
            errorMessage = userFacingMessage(for: error)
            AppFeedback.error()
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
            AppFeedback.error()
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
                AppFeedback.error()
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
