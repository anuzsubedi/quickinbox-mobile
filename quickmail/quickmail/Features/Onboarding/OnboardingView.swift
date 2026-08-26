import SwiftUI

struct OnboardingView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.appTheme) private var appTheme
    @Environment(\.colorScheme) private var colorScheme

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
    @State private var showsManualPairingHelp = false
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
                QuickMailDesign.Palette.paperGrouped.ignoresSafeArea()

                GeometryReader { geometry in
                    ScrollView {
                        onboardingContent(minHeight: geometry.size.height)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .interactiveDismissDisabled(isConnecting)
        .task {
            revealContent()
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

    private var onboardingPalette: AppThemePalette {
        appTheme.palette(for: colorScheme)
    }

    private func onboardingContent(minHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            Text("QuickMail")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(QuickMailDesign.Palette.primaryText)
                .frame(maxWidth: .infinity)
                .accessibilityAddTraits(.isHeader)
                .onboardingReveal(hasAppeared, delay: 0, reduceMotion: reduceMotion)

            Spacer(minLength: 18)

            Image("OnboardingPairingHero")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 360)
                .accessibilityHidden(true)
                .onboardingReveal(hasAppeared, delay: 0.06, reduceMotion: reduceMotion)

            Text("Your private inbox\nbegins here.")
                .font(.title.weight(.semibold))
                .foregroundStyle(QuickMailDesign.Palette.primaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)
                .onboardingReveal(hasAppeared, delay: 0.12, reduceMotion: reduceMotion)

            Spacer(minLength: 26)

            VStack(spacing: 12) {
                scanButton
                manualPairingButton

                if let errorMessage {
                    connectionError(message: errorMessage)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .onboardingReveal(hasAppeared, delay: 0.18, reduceMotion: reduceMotion)

            Spacer(minLength: 22)

            privacyPolicyFooter
                .onboardingReveal(hasAppeared, delay: 0.24, reduceMotion: reduceMotion)
        }
        .frame(maxWidth: 430)
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .frame(minHeight: minHeight)
        .frame(maxWidth: .infinity)
    }

    private var scanButton: some View {
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

                Text(isConnecting ? "Connecting..." : "Scan QR Code")
                    .font(.quickMailSemibold(17, relativeTo: .headline))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(
                onboardingPalette.interactiveTint,
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .disabled(isConnecting)
        .opacity(isConnecting ? 0.72 : 1)
        .accessibilityHint("Opens the camera to scan the pairing QR code")
    }

    private var manualPairingButton: some View {
        Button {
            AppFeedback.selection()
            errorMessage = nil
            showsManualPairing = true
        } label: {
            Text("Enter Code Manually")
                .font(.quickMailSemibold(17, relativeTo: .headline))
                .foregroundStyle(onboardingPalette.interactiveTint)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(
                    QuickMailDesign.Palette.paperRaised,
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(QuickMailDesign.Palette.separator, lineWidth: 0.5)
                }
        }
        .buttonStyle(.plain)
        .disabled(isConnecting)
        .accessibilityHint("Opens fields for the server URL and pairing code")
    }

    private var privacyPolicyFooter: some View {
        NavigationLink {
            InAppWebView(url: AppLinks.privacyPolicy)
                .navigationTitle("Privacy Policy")
                .navigationBarTitleDisplayMode(.inline)
        } label: {
            Text("Privacy Policy")
                .font(.caption)
                .underline()
                .foregroundStyle(onboardingPalette.interactiveTint)
                .frame(minHeight: 44)
        }
        .frame(maxWidth: .infinity)
    }

    private func connectionError(message: String) -> some View {
        Label {
            Text(message)
                .font(.footnote)
        } icon: {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.footnote)
        }
        .foregroundStyle(Color(uiColor: .systemRed))
        .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
        .accessibilityElement(children: .combine)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: message)
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
                            .foregroundStyle(Color(uiColor: .systemRed))
                    }
                }
            }
            .tint(onboardingPalette.interactiveTint)
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
                .tint(onboardingPalette.interactiveTint)
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

    private func revealContent() {
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
        return "QuickMail couldn't complete pairing. Try again."
    }

    private enum Field: Hashable {
        case server
        case code
    }
}

private extension View {
    func onboardingReveal(
        _ appeared: Bool,
        delay: Double,
        reduceMotion: Bool
    ) -> some View {
        self
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared || reduceMotion ? 0 : 10)
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.4).delay(delay),
                value: appeared
            )
    }
}
