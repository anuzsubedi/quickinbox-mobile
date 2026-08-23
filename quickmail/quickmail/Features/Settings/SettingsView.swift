import SwiftUI
import Combine

struct SettingsView: View {
    @Environment(AppLockController.self) private var appLock
    @StateObject private var model: SettingsViewModel
    private let onDisconnected: () -> Void

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
            devicesSection
            privacySection
            sessionSection
        }
        .navigationTitle("Settings")
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
            Text("\(model.displayName(for: device)) will be signed out of QuickMail.")
        }
        .alert("Disconnect This Device?", isPresented: $showingDisconnectConfirmation) {
            Button("Disconnect", role: .destructive) {
                Task { await disconnect(revokeOnServer: true) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This session will be revoked and QuickMail data stored on this device will be removed.")
        }
        .alert("Remove Local Data?", isPresented: $showingLocalWipeConfirmation) {
            Button("Remove", role: .destructive) {
                Task { await disconnect(revokeOnServer: false) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the saved session from this iPhone without contacting the server. The device can still be revoked from QuickMail on the web.")
        }
        .alert("Couldn’t Complete Request", isPresented: operationErrorPresented) {
            Button("OK", role: .cancel) { model.operationError = nil }
        } message: {
            Text(model.operationError ?? "Try again.")
        }
    }

    private var accountSection: some View {
        Section("Account") {
            LabeledContent("Name", value: model.currentUser.name)
            LabeledContent("Email", value: model.currentUser.email)

            if let serverURL = model.serverURL {
                LabeledContent("Server", value: serverURL.host() ?? serverURL.absoluteString)
            }

            if let manageURL = model.manageWebURL {
                Link(destination: manageURL) {
                    Label("Manage on the Web", systemImage: "safari")
                }
            }
        }
    }

    private var sendingAddressSection: some View {
        Section {
            if model.isLoading && model.addresses.isEmpty {
                loadingRow("Loading addresses")
            } else if model.addresses.isEmpty {
                Text("No sending addresses are available.")
                    .foregroundStyle(.secondary)
            } else {
                Picker("Send From", selection: $model.selectedAddressID) {
                    ForEach(model.addresses) { address in
                        VStack(alignment: .leading) {
                            Text(address.label?.isEmpty == false ? address.label! : address.address)
                            if address.label?.isEmpty == false {
                                Text(address.address)
                            }
                        }
                        .tag(address.id)
                    }
                }
            }
        } header: {
            Text("Sending Address")
        } footer: {
            Text("This address is preselected when composing and replying on this device.")
        }
    }

    private var signatureSection: some View {
        Section {
            if model.isLoading && !model.hasLoadedSignature {
                loadingRow("Loading signature")
            } else {
                TextEditor(text: $model.signatureDraft)
                    .frame(minHeight: 110)
                    .onChange(of: model.signatureDraft) { _, value in
                        if value.count > SettingsViewModel.signatureLimit {
                            model.signatureDraft = String(value.prefix(SettingsViewModel.signatureLimit))
                        }
                    }

                HStack {
                    Text("\(model.signatureDraft.count)/\(SettingsViewModel.signatureLimit)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if model.signatureSaved {
                        Label("Saved", systemImage: "checkmark")
                            .font(.callout)
                            .foregroundStyle(.green)
                    }
                    Button("Save") {
                        Task { await model.saveSignature() }
                    }
                    .disabled(model.isSavingSignature || !model.signatureHasChanges)
                }
            }
        } header: {
            Text("Account Signature")
        } footer: {
            Text("Added to sent messages unless the selected sending address has its own signature.")
        }
    }

    private var devicesSection: some View {
        Section {
            if model.isLoading && model.devices.isEmpty {
                loadingRow("Loading devices")
            } else if model.devices.isEmpty {
                Text("No connected devices were found.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(model.devices) { device in
                    HStack(spacing: 12) {
                        Image(systemName: model.symbolName(for: device))
                            .foregroundStyle(.secondary)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(model.displayName(for: device))
                                if device.isCurrent {
                                    Text("Current")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(.secondary.opacity(0.12), in: Capsule())
                                }
                            }
                            Text(model.deviceDetail(for: device))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if !device.isCurrent {
                            Button("Revoke", role: .destructive) {
                                deviceToRevoke = device
                                showingRevokeConfirmation = true
                            }
                            .disabled(model.revokingDeviceID == device.id)
                        }
                    }
                }
            }
        } header: {
            Text("Connected Devices")
        } footer: {
            Text("Revoking a device signs it out the next time it contacts your server.")
        }
    }

    private var sessionSection: some View {
        Section {
            Button("Disconnect This Device", role: .destructive) {
                showingDisconnectConfirmation = true
            }

            Button("Remove Local Data", role: .destructive) {
                showingLocalWipeConfirmation = true
            }
        } header: {
            Text("This Device")
        } footer: {
            Text("Disconnect normally to revoke server access. Remove local data only if the server cannot be reached.")
        }
    }

    private var privacySection: some View {
        Section {
            Toggle(
                "Require \(appLock.biometryName)",
                isOn: Binding(
                    get: { appLock.isEnabled },
                    set: { enabled in
                        Task { await appLock.setEnabled(enabled) }
                    }
                )
            )
            .disabled(!appLock.isAvailable && !appLock.isEnabled)

            if let message = appLock.errorMessage {
                Label(message, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        } header: {
            Text("Privacy")
        } footer: {
            Text("When enabled, QuickMail hides message content whenever you leave the app and requires biometrics when you return.")
        }
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
            AppFeedback.success()
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
            AppFeedback.success()
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
