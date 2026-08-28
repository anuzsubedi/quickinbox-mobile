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
                OnboardingPaperBackground()

                GeometryReader { layout in
                    ScrollView {
                        onboardingContent(in: layout.size)
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

    private func onboardingContent(in availableSize: CGSize) -> some View {
        let shortLayout = availableSize.height < 700
        let topSpacing = min(max(availableSize.height * 0.075, 44), 76)
        let artworkZoneHeight = min(max(availableSize.height * 0.22, 150), 220)

        return VStack(spacing: 0) {
            Spacer()
                .frame(height: topSpacing)

            Text("QuickInbox")
                .font(.onboardingBrand(42, .regular, relativeTo: .largeTitle))
                .kerning(-1.2)
                .foregroundStyle(QuickInboxDesign.Palette.primaryText)
                .accessibilityAddTraits(.isHeader)

            Spacer()
                .frame(height: shortLayout ? 20 : 30)

            if showsHero {
                heroArtwork
                    .frame(height: artworkZoneHeight)

                Spacer()
                    .frame(height: shortLayout ? 20 : 28)
            }

            (Text("Connect to your\n") + Text("private server").fontWeight(.semibold))
                .font(.onboardingBrand(34, .regular, relativeTo: .largeTitle))
                .foregroundStyle(QuickInboxDesign.Palette.primaryText)
                .multilineTextAlignment(.center)
                .lineSpacing(-2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 560)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)

            Spacer(minLength: shortLayout ? 24 : 40)

            VStack(spacing: 12) {
                if let errorMessage {
                    connectionError(message: errorMessage)
                }

                scanButton

                privacyFooter
            }
            .padding(.bottom, shortLayout ? 8 : 16)
        }
        .padding(.horizontal, horizontalPadding)
    }

    private var heroArtwork: some View {
        Image("OnboardingConnectionHero")
            .resizable()
            .scaledToFit()
            .frame(maxWidth: 560)
            .padding(.horizontal, 4)
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

private struct OnboardingPaperBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { layout in
            ZStack {
                paperColor

                Ellipse()
                    .fill(glowColor)
                    .frame(
                        width: min(layout.size.width * 1.15, 760),
                        height: min(layout.size.height * 0.34, 330)
                    )
                    .blur(radius: 54)
                    .position(
                        x: layout.size.width / 2,
                        y: layout.size.height * 0.34
                    )

                Canvas { context, size in
                    let fiberColor = colorScheme == .dark
                        ? Color.white.opacity(0.025)
                        : Color(red: 0.34, green: 0.25, blue: 0.16).opacity(0.035)

                    for index in 0..<Int(size.height / 8) {
                        let y = CGFloat(index * 8) + CGFloat((index * 3) % 5)
                        let columns = Int(size.width / 140) + 2

                        for column in 0..<columns {
                            let x = CGFloat(column * 140 + (index * 47) % 46) - 28
                            let length = CGFloat(38 + (index * 19 + column * 13) % 92)
                            var fiber = Path()
                            fiber.move(to: CGPoint(x: x, y: y))
                            fiber.addQuadCurve(
                                to: CGPoint(x: x + length, y: y + 0.6),
                                control: CGPoint(x: x + length * 0.52, y: y - 0.7)
                            )
                            context.stroke(fiber, with: .color(fiberColor), lineWidth: 0.45)
                        }
                    }
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var paperColor: Color {
        colorScheme == .dark
            ? Color(red: 0.075, green: 0.072, blue: 0.064)
            : Color(red: 0.978, green: 0.965, blue: 0.935)
    }

    private var glowColor: Color {
        colorScheme == .dark
            ? Color(red: 0.38, green: 0.33, blue: 0.25).opacity(0.16)
            : Color.white.opacity(0.52)
    }
}
