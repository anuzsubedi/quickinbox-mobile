import SwiftUI
import Combine

struct SettingsView: View {
    @Environment(AppLockController.self) private var appLock
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @StateObject private var model: SettingsViewModel
    private let onDisconnected: () -> Void

    @ScaledMetric(relativeTo: .body) private var signatureEditorHeight: CGFloat = 132

    @State private var deviceToRevoke: DeviceSession?
    @State private var showingRevokeConfirmation = false
    @State private var showingDisconnectConfirmation = false
    @State private var showingLocalWipeConfirmation = false

    init(
        api: QuickMailAPI,
        currentUser: User,
        onDisconnected: @escaping () -> Void
    ) {
        _model = StateObject(
            wrappedValue: SettingsViewModel(api: api, currentUser: currentUser)
        )
        self.onDisconnected = onDisconnected
    }

    var body: some View {
        Form {
            accountSection
            sendingAddressSection
            signatureSection
            privacySection
            devicesSection
            sessionSection
        }
        .formStyle(.grouped)
        .navigationTitle("Account")
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
        .alert("Couldn’t Complete Request", isPresented: operationErrorPresented) {
            Button("OK", role: .cancel) { model.operationError = nil }
        } message: {
            Text(model.operationError ?? "Try again.")
        }
    }

    private var accountSection: some View {
        Section {
            HStack(alignment: .center, spacing: 14) {
                ParticipantMonogram(
                    name: model.currentUser.name.isEmpty ? model.currentUser.email : model.currentUser.name,
                    isEmphasized: true,
                    size: 50
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text(model.currentUser.name)
                        .font(.headline)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)

                    Text(model.currentUser.email)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                        .textSelection(.enabled)

                    if let server = serverName {
                        Label(server, systemImage: "server.rack")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                            .textSelection(.enabled)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.vertical, 8)
            .accessibilityElement(children: .combine)

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
                    Label("Default Sender", systemImage: "paperplane")
                }
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

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        signatureStatus
                        Spacer(minLength: 8)
                        saveSignatureButton
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        signatureStatus
                        saveSignatureButton
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        } header: {
            Text("Signature")
        } footer: {
            Text("Added to sent mail unless the selected sending address has its own signature.")
        }
    }

    private var signatureStatus: some View {
        HStack(spacing: 8) {
            Text("\(model.signatureDraft.count) of \(SettingsViewModel.signatureLimit)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()

            if model.signatureSaved {
                Label("Saved", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.green)
                    .accessibilityLabel("Signature saved")
            }
        }
    }

    private var saveSignatureButton: some View {
        Button {
            Task { await model.saveSignature() }
        } label: {
            if model.isSavingSignature {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Saving…")
                }
            } else {
                Label("Save Signature", systemImage: "checkmark")
            }
        }
        .frame(minHeight: 44)
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
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: model.symbolName(for: device))
                    .font(.body.weight(.medium))
                    .foregroundStyle(device.isCurrent ? Color.accentColor : Color.secondary)
                    .frame(width: 28, height: 28)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(model.displayName(for: device))
                        .font(.body.weight(.medium))
                        .fixedSize(horizontal: false, vertical: true)

                    Text(model.deviceDetail(for: device))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if device.isCurrent {
                        Label("This Device", systemImage: "checkmark.circle.fill")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 0)

                if model.revokingDeviceID == device.id {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel("Revoking \(model.displayName(for: device))")
                }
            }
            .accessibilityElement(children: .combine)

            if !device.isCurrent {
                Button("Revoke Access", role: .destructive) {
                    deviceToRevoke = device
                    showingRevokeConfirmation = true
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .trailing)
                .disabled(model.revokingDeviceID != nil)
                .accessibilityHint("Signs this device out of QuickMail")
            }
        }
        .padding(.vertical, 4)
    }

    private var sessionSection: some View {
        Section {
            Button(role: .destructive) {
                showingDisconnectConfirmation = true
            } label: {
                Label("Disconnect This Device", systemImage: "rectangle.portrait.and.arrow.right")
            }

            Button(role: .destructive) {
                showingLocalWipeConfirmation = true
            } label: {
                Label("Remove Local Data", systemImage: "externaldrive.badge.xmark")
            }
        } header: {
            Text("Sign Out & Data")
        } footer: {
            Text("Disconnect normally to revoke access. Remove local data only when your server cannot be reached.")
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
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("App Lock")
                        Text("Protect mail when QuickMail is not active")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "lock.shield")
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

    private var serverName: String? {
        model.serverURL.map { $0.host() ?? $0.absoluteString }
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
        let error = await model.disconnect(revokeOnServer: revokeOnServer)
        onDisconnected()
        if let error {
            model.operationError = error
        }
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
        do {
            try await api.logout(
                credentialStore: credentialStore,
                revokeCurrentDevice: revokeOnServer
            )
            clearLocalPreferences()
            AppFeedback.play(.destructiveConfirmed)
            return nil
        } catch {
            // QuickMailAPI deliberately clears its credential and Keychain data even
            // when the remote revocation request fails.
            clearLocalPreferences()
            return revokeOnServer
                ? "Local data was removed, but the server could not confirm revocation. Revoke this device from QuickMail on the web."
                : error.localizedDescription
        }
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
