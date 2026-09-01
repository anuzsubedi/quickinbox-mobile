import SwiftUI

struct OnboardingView: View {
    private let api: QuickInboxAPI
    private let credentialStore: CredentialStore
    private let onAuthenticated: @MainActor (Credential, User) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.appTheme) private var appTheme
    @Environment(\.colorScheme) private var colorScheme

    @State private var serverOrigin = ""
    @State private var pairingCode = ""
    @State private var isScannerPresented = false
    @State private var isConnecting = false
    @State private var errorMessage: String?
    @State private var pendingScannedPayload: ValidatedPairingPayload?
    @State private var showsScannedOriginConfirmation = false
    @State private var showsManualPairing = false
    @State private var opensManualPairingAfterScanner = false
    @State private var showsManualPairingHelp = false
    @State private var showsPrivacyPolicy = false
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
            GeometryReader { layout in
                ScrollView {
                    onboardingContent(in: layout.size)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: layout.size.height)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
            }
            .background(QuickInboxDesign.Palette.paper)
            .toolbar(.hidden, for: .navigationBar)
        }
        .interactiveDismissDisabled(isConnecting)
        .fullScreenCover(isPresented: $isScannerPresented, onDismiss: scannerDidDismiss) {
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
            .tint(QuickInboxDesign.Palette.interactiveTint)
        }
        .alert("Check QuickInbox Server", isPresented: $showsScannedOriginConfirmation) {
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

    private func onboardingContent(in availableSize: CGSize) -> some View {
        let shortLayout = availableSize.height < 700

        return VStack(spacing: 0) {
            wordmark
                .padding(.top, 8)

            Spacer(minLength: shortLayout ? 12 : 20)

            VStack(spacing: 0) {
                if showsHero {
                    heroArtwork
                    Spacer().frame(height: shortLayout ? 18 : 22)
                }

                Text("Connect to your\nprivate server")
                    .font(.onboardingBrand(34, .medium, relativeTo: .largeTitle))
                    .kerning(-1.2)
                    .foregroundStyle(QuickInboxDesign.Palette.primaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(-2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 560)
                    .accessibilityAddTraits(.isHeader)

                Spacer().frame(height: 10)

                Text("Connect securely to continue")
                    .font(.body)
                    .foregroundStyle(QuickInboxDesign.Palette.secondaryText)
                    .multilineTextAlignment(.center)
            }

            Spacer(minLength: shortLayout ? 20 : 28)

            VStack(spacing: 12) {
                if let errorMessage {
                    connectionError(message: errorMessage)
                }

                PlatformActionCluster {
                    VStack(spacing: 10) {
                        scanButton
                        enterCodeButton
                    }
                }

                privacyFooter
            }
            .padding(.bottom, shortLayout ? 8 : 12)
        }
        .padding(.horizontal, horizontalPadding)
    }

    private var wordmark: some View {
        HStack(spacing: 6) {
            Image("QuickInboxAppIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 32, height: 32)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityHidden(true)

            Text("QuickInbox")
                .font(.onboardingBrand(16, .semibold, relativeTo: .headline))
                .kerning(-0.48)
                .foregroundStyle(QuickInboxDesign.Palette.primaryText)
        }
        .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private var heroArtwork: some View {
        Image("OnboardingConnectionHero")
            .resizable()
            .scaledToFit()
            .aspectRatio(3 / 2, contentMode: .fit)
            .frame(maxWidth: 560)
            .accessibilityHidden(true)
    }

    /// A quieter take on the app tint so the Scan action is not as punchy as
    /// glass-prominent indigo, while staying the same hue.
    private var scanButtonTint: Color {
        let base = UIColor(appTheme.palette(for: colorScheme).interactiveTint)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        guard base.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else {
            return appTheme.palette(for: colorScheme).interactiveTint
        }
        return Color(
            hue: hue,
            saturation: saturation * 0.78,
            brightness: min(brightness * 1.03, 1),
            opacity: alpha
        )
    }

    private var scanButton: some View {
        PlatformPrimaryActionButton {
            focusedField = nil
            errorMessage = nil
            isScannerPresented = true
        } label: {
            HStack(spacing: 10) {
                if isConnecting {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.headline.weight(.semibold))
                        .accessibilityHidden(true)
                }

                Text(isConnecting ? "Connecting..." : "Scan QR code")
                    .font(.headline.weight(.semibold))
            }
            .frame(maxWidth: .infinity, minHeight: 24)
        }
        .controlSize(.large)
        .tint(scanButtonTint)
        .disabled(isConnecting)
        .opacity(isConnecting ? 0.72 : 1)
        .accessibilityHint("Opens the camera to scan the pairing QR code")
    }

    private var enterCodeButton: some View {
        PlatformSecondaryActionButton {
            focusedField = nil
            errorMessage = nil
            showsManualPairing = true
        } label: {
            Label("Enter code", systemImage: "keyboard")
                .font(.headline.weight(.medium))
                .frame(maxWidth: .infinity, minHeight: 24)
        }
        .controlSize(.large)
        .disabled(isConnecting)
        .accessibilityHint("Enter the server address and pairing code manually")
    }

    private var privacyFooter: some View {
        Text(footerAttributedText)
            .font(.footnote)
            .multilineTextAlignment(.center)
            .environment(\.openURL, OpenURLAction { _ in
                showsPrivacyPolicy = true
                return .handled
            })
            .padding(.top, 4)
    }

    private var footerAttributedText: AttributedString {
        let ink = appTheme.palette(for: colorScheme).interactiveTint
        let muted = appTheme.palette(for: colorScheme).secondaryText

        var text = AttributedString("By continuing you agree to the ")
        text.foregroundColor = muted

        var link = AttributedString("privacy policy")
        link.link = AppLinks.privacyPolicy
        link.foregroundColor = ink

        return text + link
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
        .foregroundStyle(Color(uiColor: .systemRed))
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color(uiColor: .systemRed).opacity(0.09),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .accessibilityElement(children: .combine)
    }

    private var manualPairingSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    manualPairingHeader

                    pairingStepsCard

                    VStack(alignment: .leading, spacing: 16) {
                        pairingFieldCard(title: "Server Address") {
                            TextField(
                                "https://mail.example.com",
                                text: $serverOrigin,
                                prompt: Text("mail.example.com")
                                    .foregroundStyle(QuickInboxDesign.Palette.secondaryText)
                            )
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.next)
                            .focused($focusedField, equals: .server)
                            .onSubmit { focusedField = .code }
                        }

                        pairingFieldCard(title: "Pairing Code") {
                            TextField(
                                "22-character code",
                                text: $pairingCode,
                                prompt: Text("22-character code")
                                    .foregroundStyle(QuickInboxDesign.Palette.secondaryText)
                            )
                            .textContentType(.oneTimeCode)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(.system(.body, design: .monospaced, weight: .medium))
                            .submitLabel(.go)
                            .focused($focusedField, equals: .code)
                            .onSubmit(connectManually)
                        }

                        Button {
                            showsManualPairingHelp = true
                        } label: {
                            Label("Where to find these values?", systemImage: "questionmark.circle")
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(QuickInboxDesign.Palette.secondaryText)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Explains where to find the server address and pairing code")
                    }

                    if let errorMessage {
                        connectionError(message: errorMessage)
                    }

                    if isConnecting {
                        HStack(spacing: 10) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Connecting to your server...")
                                .font(.footnote)
                                .foregroundStyle(QuickInboxDesign.Palette.secondaryText)
                        }
                        .transition(.opacity)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .background(QuickInboxDesign.Palette.paper)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                PlatformPrimaryActionButton(action: connectManually) {
                    HStack(spacing: 10) {
                        if isConnecting {
                            ProgressView()
                                .controlSize(.small)
                                .tint(QuickInboxDesign.Palette.paper)
                        }
                        Text(isConnecting ? "Connecting..." : "Connect")
                            .font(.quickInboxSemibold(17, relativeTo: .headline))
                    }
                    .frame(maxWidth: .infinity, minHeight: 50)
                }
                .tint(QuickInboxDesign.Palette.interactiveTint)
                .disabled(isConnecting || serverOrigin.isEmpty || pairingCode.isEmpty)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(QuickInboxDesign.Palette.paper)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(QuickInboxDesign.Palette.separator)
                        .frame(height: 1)
                }
            }
            .navigationTitle("Enter Pairing Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(QuickInboxDesign.Palette.paper, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        focusedField = nil
                        showsManualPairing = false
                    }
                    .disabled(isConnecting)
                }
            }
            .interactiveDismissDisabled(isConnecting)
            .alert("Where to Find the Pairing Code", isPresented: $showsManualPairingHelp) {
                Button("Got It", role: .cancel) { }
            } message: {
                Text("In QuickInbox on the web, open Settings, then Connect mobile app. Copy the server URL and 22-character pairing code shown there.")
            }
        }
        .tint(QuickInboxDesign.Palette.interactiveTint)
        .preferredColorScheme(appTheme.preferredColorScheme ?? colorScheme)
        // Sheets paint their own chrome; without this, dark mode falls back to a
        // solid system black canvas behind the custom paper surfaces.
        .presentationBackground(QuickInboxDesign.Palette.paper)
        .presentationDragIndicator(.visible)
    }

    private var manualPairingHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Pair with your server")
                .font(.quickInboxSemibold(26, relativeTo: .title))
                .foregroundStyle(QuickInboxDesign.Palette.primaryText)

            Text("Copy both values from QuickInbox on the web, then connect this iPhone.")
                .font(.quickInboxBody(15, relativeTo: .callout))
                .foregroundStyle(QuickInboxDesign.Palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private var pairingStepsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("HOW IT WORKS")
                .font(.caption.weight(.semibold))
                .kerning(0.6)
                .foregroundStyle(QuickInboxDesign.Palette.secondaryText)

            pairingStepRow(number: 1, text: "Open QuickInbox on the web and sign in.")
            pairingStepRow(number: 2, text: "Go to Settings > Connect mobile app.")
            pairingStepRow(number: 3, text: "Copy the server address and pairing code shown there.")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(QuickInboxDesign.Palette.paperRaised)
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(QuickInboxDesign.Palette.separator, lineWidth: 1)
                }
        )
        .accessibilityElement(children: .combine)
    }

    private func pairingStepRow(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption.weight(.bold))
                .foregroundStyle(QuickInboxDesign.Palette.primaryText)
                .frame(width: 22, height: 22)
                .background(
                    Circle().fill(QuickInboxDesign.Palette.sageWash)
                )

            Text(text)
                .font(.quickInboxBody(14, relativeTo: .footnote))
                .foregroundStyle(QuickInboxDesign.Palette.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private func pairingFieldCard(
        title: String,
        @ViewBuilder field: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(QuickInboxDesign.Palette.secondaryText)
                .textCase(.uppercase)
                .kerning(0.6)

            field()
                .font(.quickInboxBody(16, relativeTo: .body))
                .foregroundStyle(QuickInboxDesign.Palette.primaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(QuickInboxDesign.Palette.paperRaised)
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(QuickInboxDesign.Palette.separator, lineWidth: 1)
                }
        )
        .accessibilityElement(children: .contain)
    }

    private var scannedOriginConfirmationMessage: String {
        guard let payload = pendingScannedPayload else {
            return "Confirm the server before connecting."
        }
        let host = payload.origin.host(percentEncoded: false)
            ?? payload.origin.host
            ?? payload.origin.absoluteString
        return "Only continue if \(host) is the QuickInbox server shown in your browser."
    }

    private var showsHero: Bool {
        !dynamicTypeSize.isAccessibilitySize && verticalSizeClass != .compact
    }

    private var horizontalPadding: CGFloat {
        horizontalSizeClass == .regular ? 48 : 24
    }

    private func receiveScannedValue(_ value: String) {
        do {
            let payload = try PairingPayloadValidator.validate(scannedValue: value)
            errorMessage = nil
            pendingScannedPayload = payload
            showsScannedOriginConfirmation = true
        } catch {
            errorMessage = userFacingMessage(for: error)
            AppFeedback.error()
        }
    }

    private func showManualPairingAfterScanner() {
        opensManualPairingAfterScanner = true
        isScannerPresented = false
    }

    private func scannerDidDismiss() {
        guard opensManualPairingAfterScanner else { return }
        opensManualPairingAfterScanner = false
        errorMessage = nil
        showsManualPairing = true
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
                try credentialStore.save(restorableCredential)

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
        return "QuickInbox couldn't complete pairing. Try again."
    }

    private enum Field: Hashable {
        case server
        case code
    }
}
