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
            ZStack {
                QuickInboxDesign.Palette.paper.ignoresSafeArea()

                GeometryReader { layout in
                    ScrollView {
                        onboardingContent
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: layout.size.height)
                    }
                    .scrollIndicators(.hidden)
                    .scrollBounceBehavior(.basedOnSize)
                }
            }
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

    private var onboardingContent: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 32)

            HStack {
                Text("QuickInbox")
                    .font(.onboardingBrand(24, .bold, relativeTo: .title2))
                    .kerning(0.2)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 44)
                    .background(QuickInboxDesign.Palette.paperRaised, in: Capsule())
                    .overlay { Capsule().stroke(QuickInboxDesign.Palette.separator, lineWidth: 0.5) }
                    .accessibilityAddTraits(.isHeader)

                Spacer()

                Button("Privacy") { showsPrivacyPolicy = true }
                    .font(.subheadline.weight(.semibold))
                    .frame(minHeight: 44)
            }
            .foregroundStyle(QuickInboxDesign.Palette.primaryText)
            .frame(maxWidth: 560)

            Spacer(minLength: 24)

            if showsHero {
                heroArtwork

                Spacer(minLength: 24)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Connect to your")
                    .font(.onboardingBrand(33, .regular, relativeTo: .largeTitle))

                Text("QuickInbox Server")
                    .font(.onboardingBrand(33, .semibold, relativeTo: .largeTitle))
            }
            .foregroundStyle(QuickInboxDesign.Palette.primaryText)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: 560, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            VStack(alignment: .leading, spacing: 12) {
                Text("Open QuickInbox on the web, choose Settings > Connect mobile app, then scan the code shown there.")
                    .font(.callout)
                    .foregroundStyle(QuickInboxDesign.Palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Label("Connected over HTTPS. Pairing credentials stay protected in Keychain.", systemImage: "lock.shield")
                    .font(.footnote)
                    .foregroundStyle(QuickInboxDesign.Palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: 560, alignment: .leading)
            .padding(.top, 18)

            Spacer(minLength: 40)

            VStack(spacing: 20) {
                if let errorMessage {
                    connectionError(message: errorMessage)
                }

                scanButton

                privacyFooter
            }
            .padding(.bottom, 16)
        }
        .padding(.horizontal, horizontalPadding)
    }

    private var heroArtwork: some View {
        Image("OnboardingConnectionHero")
            .resizable()
            .scaledToFit()
            .frame(maxWidth: 560)
            .padding(.horizontal, 8)
            .accessibilityHidden(true)
    }

    private var scanButton: some View {
        Button {
            focusedField = nil
            errorMessage = nil
            isScannerPresented = true
        } label: {
            HStack(spacing: 11) {
                if isConnecting {
                    ProgressView()
                        .controlSize(.small)
                        .tint(QuickInboxDesign.Palette.primaryText)
                } else {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: 20, weight: .semibold))
                        .accessibilityHidden(true)
                }

                Text(isConnecting ? "Connecting..." : "Scan QR Code")
                    .font(.system(.headline, design: .default, weight: .semibold))
            }
            .foregroundStyle(QuickInboxDesign.Palette.primaryText)
            .frame(maxWidth: .infinity, minHeight: 58)
            .modifier(ScanButtonSurfaceModifier())
            .contentShape(Rectangle())
        }
        .buttonStyle(QuickInboxPressButtonStyle())
        .disabled(isConnecting)
        .opacity(isConnecting ? 0.72 : 1)
        .accessibilityHint("Opens the camera to scan the pairing QR code")
    }

    private var privacyFooter: some View {
        Text(footerAttributedText)
            .font(.callout)
            .multilineTextAlignment(.center)
            .environment(\.openURL, OpenURLAction { _ in
                showsPrivacyPolicy = true
                return .handled
            })
            .padding(.top, 6)
    }

    private var footerAttributedText: AttributedString {
        let ink = appTheme.palette(for: colorScheme).primaryText
        let muted = appTheme.palette(for: colorScheme).secondaryText

        var text = AttributedString("By continuing, you agree to the ")
        text.foregroundColor = muted

        var link = AttributedString("Privacy Policy")
        link.link = AppLinks.privacyPolicy
        link.foregroundColor = ink

        var trailing = AttributedString(".")
        trailing.foregroundColor = muted

        return text + link + trailing
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
        return "QuickInbox couldn't complete pairing. Try again."
    }

    private enum Field: Hashable {
        case server
        case code
    }
}

private struct ScanButtonSurfaceModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular.interactive(), in: .capsule)
        } else {
            content.background {
                RoundedRectangle(cornerRadius: 29, style: .continuous)
                    .fill(QuickInboxDesign.Palette.paperRaised)
                    .overlay {
                        RoundedRectangle(cornerRadius: 29, style: .continuous)
                            .strokeBorder(QuickInboxDesign.Palette.separator, lineWidth: 1)
                    }
                    .shadow(
                        color: .black.opacity(0.08),
                        radius: 16,
                        x: 0,
                        y: 8
                    )
            }
        }
    }
}
