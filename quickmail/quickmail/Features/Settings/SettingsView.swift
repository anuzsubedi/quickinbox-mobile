import SwiftUI
import Combine

struct SettingsView: View {
    @Environment(AppLockController.self) private var appLock
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @StateObject private var model: SettingsViewModel
    @AppStorage(AppPreferences.showRemoteImagesByDefault) private var showRemoteImagesByDefault = false
    private let onDisconnected: (String?) -> Void

    @ScaledMetric(relativeTo: .body) private var signatureEditorHeight: CGFloat = 104

    @State private var deviceToRevoke: DeviceSession?
    @State private var showingRevokeConfirmation = false
    @State private var showingDisconnectConfirmation = false
    @State private var showingLocalWipeConfirmation = false

    init(
        api: QuickMailAPI,
        currentUser: User,
        onDisconnected: @escaping (String?) -> Void
    ) {
        _model = StateObject(
            wrappedValue: SettingsViewModel(api: api, currentUser: currentUser)
        )
        self.onDisconnected = onDisconnected
    }

    var body: some View {
        Form {
            Section {
                NavigationLink {
                    accountPage
                } label: {
                    accountNavigationLabel
                }
            }

            Section("Preferences") {
                NavigationLink {
                    sendingPage
                } label: {
                    settingsDestinationLabel(
                        "Composing",
                        systemImage: "square.and.pencil"
                    )
                }

                NavigationLink {
                    privacyPage
                } label: {
                    settingsDestinationLabel(
                        "Privacy & Security",
                        systemImage: "lock.shield",
                        detail: appLock.isEnabled ? "On" : "Off"
                    )
                }

            }

            Section("Access") {
                NavigationLink {
                    devicesPage
                } label: {
                    settingsDestinationLabel(
                        "Connected Devices",
                        systemImage: "laptopcomputer.and.iphone",
                        detail: model.isLoading && model.devices.isEmpty
                            ? nil
                            : "\(model.devices.count)"
                    )
                }

                NavigationLink {
                    connectionPage
                } label: {
                    settingsDestinationLabel(
                        "Server & Session",
                        systemImage: "server.rack"
                    )
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            appLock.refreshAvailability()
            await model.loadIfNeeded()
        }
        .refreshable { await model.load() }
        .alert(
            "Revoke Device?",
            isPresented: $showingRevokeConfirmation,
            presenting: deviceToRevoke
        ) { device in
            Button("Revoke", role: .destructive) {
                Task { await model.revoke(device) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { device in
            Text("\(model.displayName(for: device)) will lose access the next time it contacts your server.")
        }
        .alert("Couldn’t Complete Request", isPresented: operationErrorPresented) {
            Button("OK", role: .cancel) { model.operationError = nil }
        } message: {
            Text(model.operationError ?? "Try again.")
        }
    }

    private var accountPage: some View {
        Form {
            accountSection
        }
        .formStyle(.grouped)
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var sendingPage: some View {
        Form {
            sendingAddressSection
            signatureSection
        }
        .formStyle(.grouped)
        .navigationTitle("Composing")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                saveSignatureToolbarButton
            }
        }
    }

    private var privacyPage: some View {
        Form {
            privacySection
            remoteImagesSection
        }
        .formStyle(.grouped)
        .navigationTitle("Privacy & Security")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var devicesPage: some View {
        Form {
            devicesSection
        }
        .formStyle(.grouped)
        .navigationTitle("Connected Devices")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await model.load() }
    }

    private var connectionPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                serverSection
                disconnectSection
                localDataSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 40)
            .frame(maxWidth: QuickMailDesign.contentMaxWidth)
            .frame(maxWidth: .infinity)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Server & Session")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Disconnect This Device?", isPresented: $showingDisconnectConfirmation) {
            Button("Disconnect", role: .destructive) {
                Task { await disconnect(revokeOnServer: true) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("QuickMail will revoke this session and remove its saved account and mailbox data from this device.")
        }
        .alert("Remove Local Data?", isPresented: $showingLocalWipeConfirmation) {
            Button("Remove", role: .destructive) {
                Task { await disconnect(revokeOnServer: false) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("QuickMail will remove its saved account and mailbox data without contacting your server. This device may still need to be revoked on the web.")
        }
    }

    private var accountNavigationLabel: some View {
        HStack(spacing: 14) {
            ParticipantMonogram(
                name: displayName,
                isEmphasized: true,
                size: 44
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(displayName)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)

                Text(model.currentUser.email)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Shows account details")
    }

    private func settingsDestinationLabel(
        _ title: String,
        systemImage: String,
        detail: String? = nil
    ) -> some View {
        HStack(spacing: 12) {
            Label(title, systemImage: systemImage)

            Spacer(minLength: 8)

            if let detail {
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
            .frame(minHeight: 32)
    }

    private var accountSection: some View {
        Section {
            LabeledContent("Name") {
                Text(displayName)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            LabeledContent("Email") {
                    Text(model.currentUser.email)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
            }

            if let manageURL = model.manageWebURL {
                Link(destination: manageURL) {
                    Label("Manage Account on the Web", systemImage: "safari")
                }
                .accessibilityHint("Opens your QuickMail account settings in the browser")
            }
        } footer: {
            Text("This app stays connected directly to your QuickMail server.")
        }
    }

    private var serverSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Connection")
                .font(.headline)
                .foregroundStyle(.secondary)

            if let serverName {
                HStack(spacing: 14) {
                    Image(systemName: "server.rack")
                        .font(.body.weight(.medium))
                        .foregroundStyle(QuickMailDesign.Palette.signalInk)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("QuickMail Server")
                            .font(.body.weight(.medium))
                        Text(serverName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }

                    Spacer(minLength: 8)

                    if let scheme = model.serverURL?.scheme?.uppercased() {
                        Label(scheme, systemImage: "lock.fill")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(16)
                .background(
                    Color(uiColor: .secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
            } else if model.isLoading {
                loadingRow("Loading server details")
                    .padding(.vertical, 12)
            } else {
                Label("Server details unavailable", systemImage: "server.rack")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 12)
            }

            Text("This device connects directly to your QuickMail server over HTTPS.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var sendingAddressSection: some View {
        Section {
            if model.isLoading && model.addresses.isEmpty {
                loadingRow("Loading sending addresses")
            } else if model.addresses.isEmpty {
                Label("No sending addresses available", systemImage: "at.badge.minus")
                    .foregroundStyle(.secondary)
            } else {
                Picker(selection: $model.selectedAddressID) {
                    ForEach(model.addresses) { address in
                        Text(addressTitle(address))
                            .tag(address.id)
                    }
                } label: {
                    Text("Default Sender")
                }
                .pickerStyle(.navigationLink)
            }
        } header: {
            Text("Sending")
        } footer: {
            Text("QuickMail preselects this address when you start a new message on this device.")
        }
    }

    private var signatureSection: some View {
        Section {
            if model.isLoading && !model.hasLoadedSignature {
                loadingRow("Loading signature")
            } else {
                ZStack(alignment: .topLeading) {
                    if model.signatureDraft.isEmpty {
                        Text("Add a signature to new messages…")
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 8)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }

                    TextEditor(text: $model.signatureDraft)
                        .frame(minHeight: min(signatureEditorHeight, 190))
                        .scrollContentBackground(.hidden)
                        .accessibilityLabel("Email signature")
                        .onChange(of: model.signatureDraft) { _, value in
                            if value.count > SettingsViewModel.signatureLimit {
                                model.signatureDraft = String(value.prefix(SettingsViewModel.signatureLimit))
                            }
                        }
                }
            }
        } header: {
            Text("Signature")
        } footer: {
            VStack(alignment: .leading, spacing: 5) {
                signatureStatus
                Text("Added to sent mail unless the selected sending address has its own signature.")
            }
        }
    }

    private var signatureStatus: some View {
        HStack(spacing: 12) {
            Text("\(model.signatureDraft.count) / \(SettingsViewModel.signatureLimit.formatted())")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .contentTransition(.numericText())

            Spacer(minLength: 8)

            if model.signatureSaved {
                Label("Saved", systemImage: "checkmark")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Signature saved")
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var saveSignatureToolbarButton: some View {
        Button {
            Task { await model.saveSignature() }
        } label: {
            if model.isSavingSignature {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel("Saving signature")
            } else {
                Text("Save")
            }
        }
        .disabled(model.isSavingSignature || !model.signatureHasChanges)
        .accessibilityHint(
            model.signatureHasChanges
                ? "Saves the signature to your account"
                : "No unsaved signature changes"
        )
    }

    private var devicesSection: some View {
        Section {
            if model.isLoading && model.devices.isEmpty {
                loadingRow("Loading connected devices")
            } else if model.devices.isEmpty {
                Label("No connected devices found", systemImage: "rectangle.stack.badge.minus")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(model.devices) { device in
                    deviceRow(device)
                }
            }
        } header: {
            Text("Connected Devices")
        } footer: {
            Text("Revoke any device you no longer recognize or use.")
        }
    }

    private func deviceRow(_ device: DeviceSession) -> some View {
        HStack(spacing: 12) {
            Image(systemName: model.symbolName(for: device))
                .font(.body.weight(.medium))
                .foregroundStyle(device.isCurrent ? Color.accentColor : Color.secondary)
                .frame(width: 32, height: 44, alignment: .center)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(model.displayName(for: device))
                    .font(.body.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)

                Text(model.deviceDetail(for: device))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)

            Spacer(minLength: 8)

            deviceAccessory(device)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func deviceAccessory(_ device: DeviceSession) -> some View {
        if model.revokingDeviceID == device.id {
            ProgressView()
                .controlSize(.small)
                .frame(width: 44, height: 44)
                .accessibilityLabel("Revoking \(model.displayName(for: device))")
        } else if device.isCurrent {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(.secondary)
                .frame(width: 44, height: 44)
                .accessibilityLabel("This Device")
        } else {
            Menu {
                Button("Revoke Access", systemImage: "person.crop.circle.badge.minus", role: .destructive) {
                    deviceToRevoke = device
                    showingRevokeConfirmation = true
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(model.revokingDeviceID != nil)
            .accessibilityLabel("Actions for \(model.displayName(for: device))")
            .accessibilityHint("Includes an option to revoke access")
        }
    }

    private var disconnectSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Session")
                .font(.headline)
                .foregroundStyle(.secondary)

            FloatingActionButton(role: .destructive) {
                showingDisconnectConfirmation = true
            } label: {
                disconnectButtonLabel(
                    "Disconnect"
                )
            }
            .tint(.red)
            .controlSize(.regular)
            .disabled(model.isDisconnecting)

            Text("Revokes this session on your server and removes the account and cached mail from this device.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func disconnectButtonLabel(_ title: String) -> some View {
        Group {
            if model.isDisconnecting {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 120, height: 36)
                    .accessibilityLabel("Disconnecting")
            } else {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .frame(minHeight: 32)
            }
        }
    }

    private var localDataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recovery")
                .font(.headline)
                .foregroundStyle(.secondary)

            FloatingActionButton(role: .destructive) {
                showingLocalWipeConfirmation = true
            } label: {
                disconnectButtonLabel("Remove Local Data")
            }
            .tint(.red)
            .controlSize(.regular)
            .disabled(model.isDisconnecting)

            Text("Use only when your server cannot be reached. You may still need to revoke this device on the web.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var privacySection: some View {
        Section {
            Toggle(
                isOn: Binding(
                    get: { appLock.isEnabled },
                    set: { enabled in
                        Task { await appLock.setEnabled(enabled) }
                    }
                )
            ) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("App Lock")
                    Text("Require authentication when returning to QuickMail")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .disabled(!appLock.isAvailable && !appLock.isEnabled)

            if let message = appLock.errorMessage {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .accessibilityLabel("App Lock unavailable. \(message)")
            }

        } header: {
            Text("Privacy")
        } footer: {
            Text("When enabled, QuickMail hides message content after you leave the app and asks for \(appLock.biometryName) or your device passcode when you return.")
        }
    }

    private var remoteImagesSection: some View {
        Section {
            Toggle(isOn: $showRemoteImagesByDefault) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Show Email Images")
                    Text("Automatically load images from the internet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Email Images")
        } footer: {
            Text("Remote images can let senders know when and where you opened a message. When disabled, you can still show images for an individual email.")
        }
    }

    private var serverName: String? {
        model.serverURL.map { $0.host() ?? $0.absoluteString }
    }

    private var displayName: String {
        let name = model.currentUser.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? model.currentUser.email : name
    }

    private func addressTitle(_ address: MailAddress) -> String {
        guard let label = address.label?.trimmingCharacters(in: .whitespacesAndNewlines),
              !label.isEmpty else {
            return address.address
        }
        return "\(label) — \(address.address)"
    }

    private func loadingRow(_ title: String) -> some View {
        HStack(spacing: 10) {
            ProgressView()
            Text(title)
                .foregroundStyle(.secondary)
        }
    }

    private var operationErrorPresented: Binding<Bool> {
        Binding(
            get: { model.operationError != nil },
            set: { if !$0 { model.operationError = nil } }
        )
    }

    @MainActor
    private func disconnect(revokeOnServer: Bool) async {
        let warning = await model.disconnect(revokeOnServer: revokeOnServer)
        onDisconnected(warning)
    }
}

@MainActor
private final class SettingsViewModel: ObservableObject {
    static let signatureLimit = 1_000
    @Published private(set) var addresses: [MailAddress] = []
    @Published private(set) var devices: [DeviceSession] = []
    @Published var selectedAddressID: String {
        didSet { UserDefaults.standard.set(selectedAddressID, forKey: AppPreferences.selectedSendingAddressID) }
    }
    @Published var signatureDraft = "" {
        didSet {
            if signatureDraft != savedSignature { signatureSaved = false }
        }
    }
    @Published private(set) var isLoading = false
    @Published private(set) var isSavingSignature = false
    @Published private(set) var hasLoadedSignature = false
    @Published private(set) var signatureSaved = false
    @Published private(set) var revokingDeviceID: String?
    @Published private(set) var isDisconnecting = false
    @Published var operationError: String?
    @Published private(set) var serverURL: URL?
    @Published private(set) var manageWebURL: URL?

    let currentUser: User

    private let api: QuickMailAPI
    private let credentialStore = CredentialStore()
    private var savedSignature = ""
    private var hasLoaded = false

    var signatureHasChanges: Bool { hasLoadedSignature && signatureDraft != savedSignature }

    init(api: QuickMailAPI, currentUser: User) {
        self.api = api
        self.currentUser = currentUser
        selectedAddressID = UserDefaults.standard.string(forKey: AppPreferences.selectedSendingAddressID) ?? ""
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        await load()
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        operationError = nil
        defer { isLoading = false }

        do {
            async let fetchedAddresses = api.addresses()
            async let fetchedSignature = api.signature()
            async let fetchedDevices = api.devices()
            let credential = await api.currentCredential
            let (newAddresses, newSignature, newDevices) = try await (
                fetchedAddresses,
                fetchedSignature,
                fetchedDevices
            )

            addresses = newAddresses
            devices = newDevices
            savedSignature = newSignature
            signatureDraft = newSignature
            hasLoadedSignature = true
            installValidSelectedAddress()
            installServerURLs(from: credential?.origin)
            hasLoaded = true
        } catch {
            operationError = error.localizedDescription
        }
    }

    func saveSignature() async {
        guard signatureHasChanges, !isSavingSignature else { return }
        isSavingSignature = true
        operationError = nil
        defer { isSavingSignature = false }

        do {
            let signature = try await api.updateSignature(signatureDraft)
            savedSignature = signature
            signatureDraft = signature
            signatureSaved = true
            AppFeedback.success()
        } catch {
            operationError = error.localizedDescription
            AppFeedback.error()
        }
    }

    func revoke(_ device: DeviceSession) async {
        guard !device.isCurrent, revokingDeviceID == nil else { return }
        revokingDeviceID = device.id
        operationError = nil
        defer { revokingDeviceID = nil }

        do {
            try await api.revokeDevice(id: device.id)
            devices.removeAll { $0.id == device.id }
            AppFeedback.play(.destructiveConfirmed)
        } catch {
            operationError = error.localizedDescription
            AppFeedback.error()
        }
    }

    /// Returns a warning only when local data was removed but remote revocation failed.
    func disconnect(revokeOnServer: Bool) async -> String? {
        guard !isDisconnecting else { return nil }
        isDisconnecting = true
        defer { isDisconnecting = false }

        var revocationError: Error?
        if revokeOnServer {
            do {
                if let currentDevice = devices.first(where: \.isCurrent) {
                    try await api.revokeDevice(id: currentDevice.id)
                } else {
                    try await api.logout(
                        credentialStore: credentialStore,
                        revokeCurrentDevice: true
                    )
                }
            } catch {
                revocationError = error
            }
        }

        do {
            // Always finish the local wipe, including after a successful remote
            // revocation makes the bearer credential unusable.
            try await api.logout(
                credentialStore: credentialStore,
                revokeCurrentDevice: false
            )
        } catch {
            revocationError = revocationError ?? error
        }

        clearLocalPreferences()
        AppFeedback.play(.destructiveConfirmed)

        if revokeOnServer, revocationError != nil {
            return "This iPhone was disconnected locally, but the server could not confirm revocation. Revoke it from QuickMail on the web."
        }
        return nil
    }

    func displayName(for device: DeviceSession) -> String {
        let name = device.deviceName?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let name, !name.isEmpty { return name }
        return device.devicePlatform == nil ? "Web Session" : "Mobile Device"
    }

    func symbolName(for device: DeviceSession) -> String {
        switch device.devicePlatform?.lowercased() {
        case "ios": "iphone"
        case "android": "rectangle.portrait"
        default: "desktopcomputer"
        }
    }

    func deviceDetail(for device: DeviceSession) -> String {
        if let lastSeen = device.lastSeenAt {
            return "Active \(lastSeen.formatted(.relative(presentation: .named)))"
        }
        return "Connected \(device.createdAt.formatted(date: .abbreviated, time: .omitted))"
    }

    private func installValidSelectedAddress() {
        if addresses.contains(where: { $0.id == selectedAddressID }) { return }
        selectedAddressID = addresses.first(where: \.isDefault)?.id ?? addresses.first?.id ?? ""
    }

    private func installServerURLs(from origin: URL?) {
        serverURL = origin
        guard let origin else {
            manageWebURL = nil
            return
        }
        manageWebURL = origin.appending(path: "settings")
    }

    private func clearLocalPreferences() {
        selectedAddressID = ""
        UserDefaults.standard.removeObject(forKey: AppPreferences.selectedSendingAddressID)
    }
}
