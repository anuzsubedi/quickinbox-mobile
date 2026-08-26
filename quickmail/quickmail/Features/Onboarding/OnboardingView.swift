import SwiftUI

struct OnboardingView: View {
    private let api: QuickMailAPI
    private let credentialStore: CredentialStore
    private let onAuthenticated: @MainActor (Credential, User) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    @State private var serverOrigin = ""
    @State private var pairingCode = ""
    @State private var isScannerPresented = false
    @State private var isConnecting = false
    @State private var errorMessage: String?
    @State private var pendingScannedPayload: ValidatedPairingPayload?
    @State private var showsScannedOriginConfirmation = false
    @State private var showsManualPairing = false
    @State private var showsManualPairingHelp = false
    @State private var showsPrivacyPolicy = false
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
                OnboardingStyle.canvas.ignoresSafeArea()

                VStack(spacing: 0) {
                    onboardingHeader

                    ScrollView {
                        onboardingContent
                    }
                    .scrollIndicators(.hidden)
                    .scrollBounceBehavior(.basedOnSize)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                primaryActionRegion
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .preferredColorScheme(.light)
        .interactiveDismissDisabled(isConnecting)
        .fullScreenCover(isPresented: $isScannerPresented) {
            QRScannerView(
                onScan: receiveScannedValue,
                onEnterManually: showManualPairingAfterScanner
            )
        }
        .sheet(isPresented: $showsManualPairing) {
            manualPairingSheet
        }
        .sheet(isPresented: $showsPrivacyPolicy) {
            NavigationStack {
                InAppWebView(url: AppLinks.privacyPolicy)
                    .navigationTitle("Privacy Policy")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showsPrivacyPolicy = false }
                        }
                    }
            }
            .tint(OnboardingStyle.coral)
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

    private var onboardingHeader: some View {
        HStack(alignment: .center, spacing: 16) {
            Text("QuickMail")
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(OnboardingStyle.ink)
                .accessibilityAddTraits(.isHeader)

            Spacer(minLength: 12)

            Button("Privacy") {
                showsPrivacyPolicy = true
            }
            .font(.system(.subheadline, design: .default, weight: .semibold))
            .foregroundStyle(OnboardingStyle.coral)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
            .accessibilityHint("Opens the QuickMail Privacy Policy")
        }
        .frame(maxWidth: 620)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, horizontalPadding)
        .padding(.top, 6)
        .padding(.bottom, 6)
    }

    private var onboardingContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            if showsHero {
                pairingHero
            }

            VStack(alignment: .leading, spacing: 0) {
                Text("Connect to your hosted QuickMail server")
                    .font(.system(.largeTitle, design: .default, weight: .bold))
                    .foregroundStyle(OnboardingStyle.ink)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Open QuickMail on the web, then go to Settings > Connect mobile app. Scan the code shown there.")
                    .font(.system(.body, design: .default, weight: .regular))
                    .foregroundStyle(OnboardingStyle.mutedInk)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 16)

                trustLine

                if let errorMessage {
                    connectionError(message: errorMessage)
                }
            }
        }
        .frame(maxWidth: 620, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, horizontalPadding)
        .padding(.top, showsHero ? 2 : 24)
        .padding(.bottom, 28)
    }

    private var pairingHero: some View {
        Image("OnboardingConnectionHero")
            .resizable()
            .scaledToFit()
            .frame(maxWidth: 560)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                OnboardingStyle.artMat,
                in: RoundedRectangle(cornerRadius: 28, style: .continuous)
            )
            .accessibilityHidden(true)
            .padding(.bottom, 30)
    }

    private var trustLine: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "lock.shield")
                .font(.footnote.weight(.semibold))
                .accessibilityHidden(true)

            Text("Connection uses HTTPS. Pairing credentials are stored in Keychain.")
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(OnboardingStyle.mutedInk)
        .padding(.top, 18)
        .accessibilityElement(children: .combine)
    }

    private var primaryActionRegion: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(OnboardingStyle.separator)
                .frame(height: 1)
                .accessibilityHidden(true)

            Button {
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
                            .font(.headline.weight(.semibold))
                    }

                    Text(isConnecting ? "Connecting..." : "Scan QR code")
                        .font(.system(.headline, design: .default, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(
                    OnboardingStyle.coral,
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
            }
            .buttonStyle(.plain)
            .disabled(isConnecting)
            .opacity(isConnecting ? 0.72 : 1)
            .accessibilityHint("Opens the camera to scan the pairing QR code")
            .padding(.horizontal, horizontalPadding)
            .padding(.top, 12)
            .padding(.bottom, 8)
        }
        .background(OnboardingStyle.canvas)
    }

    private func connectionError(message: String) -> some View {
        Label {
            Text(message)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.callout.weight(.semibold))
        }
        .foregroundStyle(OnboardingStyle.error)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            OnboardingStyle.error.opacity(0.09),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .padding(.top, 20)
        .accessibilityElement(children: .combine)
    }

    private var manualPairingSheet: some View {
        NavigationStack {
            QuickMailForm {
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
                            .foregroundStyle(OnboardingStyle.error)
                    }
                }
            }
            .tint(OnboardingStyle.coral)
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

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showsManualPairingHelp = true
                    } label: {
                        Image(systemName: "info.circle")
                    }
                    .accessibilityLabel("Where to find the pairing code")
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
                        Text(isConnecting ? "Connecting..." : "Connect")
                            .font(.quickMailSemibold(17, relativeTo: .headline))
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                .tint(OnboardingStyle.coral)
                .disabled(isConnecting || serverOrigin.isEmpty || pairingCode.isEmpty)
                .padding(16)
                .quickMailBarSurface()
            }
            .interactiveDismissDisabled(isConnecting)
            .alert("Where to Find the Pairing Code", isPresented: $showsManualPairingHelp) {
                Button("Got It", role: .cancel) { }
            } message: {
                Text("In QuickMail on the web, open Settings, then Connect mobile app. Copy the server URL and 22-character pairing code shown there.")
            }
        }
    }

    private var scannedOriginConfirmationMessage: String {
        guard let payload = pendingScannedPayload else {
            return "Confirm the server before connecting."
        }
        let host = payload.origin.host(percentEncoded: false)
            ?? payload.origin.host
            ?? payload.origin.absoluteString
        return "Only continue if \(host) is the QuickMail server shown in your browser."
    }

    private var showsHero: Bool {
        !dynamicTypeSize.isAccessibilitySize && verticalSizeClass != .compact
    }

    private var horizontalPadding: CGFloat {
        horizontalSizeClass == .regular ? 32 : 20
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

    private func showManualPairingAfterScanner() {
        isScannerPresented = false
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(250))
            errorMessage = nil
            showsManualPairing = true
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
        return "QuickMail couldn't complete pairing. Try again."
    }

    private enum Field: Hashable {
        case server
        case code
    }
}

private enum OnboardingStyle {
    static let canvas = Color(red: 1.0, green: 0.976, blue: 0.941)
    static let artMat = Color(red: 0.965, green: 0.850, blue: 0.790)
    static let ink = Color(red: 0.122, green: 0.161, blue: 0.196)
    static let mutedInk = Color(red: 0.310, green: 0.357, blue: 0.345)
    static let coral = Color(red: 0.875, green: 0.365, blue: 0.302)
    static let separator = Color(red: 0.122, green: 0.161, blue: 0.196).opacity(0.12)
    static let error = Color(uiColor: .systemRed)
}
