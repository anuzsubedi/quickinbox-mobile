import SwiftUI

struct OnboardingView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.appTheme) private var appTheme
    @Environment(\.colorScheme) private var colorScheme

    private let api: QuickInboxAPI
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
        api: QuickInboxAPI,
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
                onboardingBackground

                GeometryReader { geometry in
                    ScrollView {
                        onboardingContent(minHeight: geometry.size.height)
                    }
                    .scrollBounceBehavior(.basedOnSize)
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
        .alert("Check QuickInbox Server", isPresented: $showsScannedOriginConfirmation) {
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

    private var onboardingBackground: some View {
        let palette = appTheme.palette(for: colorScheme)
        return ZStack {
            QuickInboxDesign.Palette.paperGrouped

            LinearGradient(
                colors: [
                    palette.signalInk.opacity(0.13),
                    .clear
                ],
                startPoint: .topLeading,
                endPoint: .center
            )

            RadialGradient(
                colors: [
                    Color.accentColor.opacity(0.08),
                    .clear
                ],
                center: .bottomTrailing,
                startRadius: 0,
                endRadius: 360
            )
        }
        .ignoresSafeArea()
    }

    private func onboardingContent(minHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            brand

            introduction
                .padding(.top, 30)

            pairingHero
                .padding(.top, 22)

            webLocation
                .padding(.top, 18)

            securityNote
                .padding(.top, 12)

            Spacer(minLength: 28)

            connectionError
                .padding(.top, errorMessage == nil ? 0 : 20)
        }
        .frame(maxWidth: 480)
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 28)
        .frame(minHeight: minHeight)
        .frame(maxWidth: .infinity)
        .opacity(hasAppeared ? 1 : 0)
    }

    private var brand: some View {
        HStack(spacing: 9) {
            Image("LaunchIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 52, height: 40)

            Text("QuickInbox")
                .font(.title3.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .accessibilityElement(children: .combine)
    }

    private var introduction: some View {
        VStack(spacing: 10) {
            Text("Pair your iPhone")
                .font(.largeTitle.weight(.bold))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text("Scan the one-time code shown in QuickInbox on the web.")
                .font(.body)
                .foregroundStyle(QuickInboxDesign.Palette.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }

    private var pairingHero: some View {
        Image("OnboardingPairingHero")
            .resizable()
            .scaledToFit()
            .aspectRatio(3 / 2, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(QuickInboxDesign.Palette.separator, lineWidth: 0.5)
            }
            .accessibilityHidden(true)
    }

    private var webLocation: some View {
        Label {
            Text("Settings  ›  Connect mobile app")
                .font(.subheadline.weight(.medium))
        } icon: {
            Image(systemName: "safari.fill")
                .foregroundStyle(.tint)
        }
        .foregroundStyle(QuickInboxDesign.Palette.secondaryText)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("On the web, open Settings, then Connect mobile app")
    }

    @ViewBuilder
    private var connectionError: some View {
        if let errorMessage {
            Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                .font(.callout)
                .foregroundStyle(QuickInboxDesign.Palette.primaryText)
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
            .foregroundStyle(QuickInboxDesign.Palette.secondaryText)
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

            manualPairingButton
        }
        .frame(maxWidth: 480)
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity)
        .background(.bar)
    }

    private var manualPairingButton: some View {
        Button {
            AppFeedback.selection()
            errorMessage = nil
            showsManualPairing = true
        } label: {
            Label("Enter Code Manually", systemImage: "keyboard")
                .font(.subheadline.weight(.semibold))
                .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .foregroundStyle(QuickInboxDesign.Palette.primaryText)
        .disabled(isConnecting)
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
                    Text("Find both values in QuickInbox on the web.")
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
        return "Only continue if \(host) is the QuickInbox server shown in your browser."
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
                    deviceName: "QuickInbox for iOS"
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
        return "QuickInbox couldn’t complete pairing. Try again."
    }

    private enum Field: Hashable {
        case server
        case code
    }
}
