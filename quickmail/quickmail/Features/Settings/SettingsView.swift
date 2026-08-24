import SwiftUI
import Combine

struct SettingsView: View {
    @Environment(AppLockController.self) private var appLock
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var model: SettingsViewModel
    @AppStorage(AppPreferences.showRemoteImagesByDefault) private var showRemoteImagesByDefault = false
    @AppStorage(AppPreferences.appThemeID) private var appThemeID = AppThemeRegistry.defaultThemeID
    private let onDisconnected: (String?) -> Void

    private var appearanceSummary: String {
        selectedTheme.title
    }

    private var selectedTheme: AppTheme {
        AppThemeRegistry.theme(id: appThemeID)
    }

    private var settingsPalette: AppThemePalette {
        selectedTheme.palette(for: colorScheme)
    }

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
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                accountOverview

                settingsGroup(title: "Personalization") {
                    NavigationLink {
                        appearancePage
                    } label: {
                        settingsDestinationLabel(
                            "Appearance",
                            systemImage: "paintpalette",
                            detail: appearanceSummary
                        )
                    }
                }

                settingsGroup(title: "Mail") {
                    NavigationLink {
                        sendingPage
                    } label: {
                        settingsDestinationLabel(
                            "Composing",
                            systemImage: "square.and.pencil"
                        )
                    }

                    settingsGroupDivider

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

                settingsGroup(title: "Account Access") {
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

                    settingsGroupDivider

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
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 40)
            .frame(maxWidth: QuickMailDesign.contentMaxWidth)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .background(settingsPalette.grouped)
        .toolbarBackground(settingsPalette.paper, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
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
        .environment(\.appTheme, selectedTheme)
    }

    private var accountOverview: some View {
        NavigationLink {
            accountPage
        } label: {
            HStack(alignment: dynamicTypeSize.isAccessibilitySize ? .top : .center, spacing: 14) {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 12) {
                        ParticipantMonogram(
                            name: displayName,
                            isEmphasized: true,
                            size: 52
                        )
                        accountOverviewText
                    }
                } else {
                    ParticipantMonogram(
                        name: displayName,
                        isEmphasized: true,
                        size: 52
                    )
                    accountOverviewText
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(QuickMailDesign.Palette.secondaryText)
                    .padding(.top, dynamicTypeSize.isAccessibilitySize ? 8 : 0)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 60)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Shows account details")
        .modifier(SettingsPanelModifier())
    }

    private var accountOverviewText: some View {
        VStack(alignment: .leading, spacing: 3) {
                    Text(displayName)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(QuickMailDesign.Palette.primaryText)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)

                    Text(model.currentUser.email)
                        .font(.subheadline)
                        .foregroundStyle(QuickMailDesign.Palette.secondaryText)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
        }
    }

    private var appearanceOverview: some View {
        VStack(alignment: .leading, spacing: 14) {
            settingsOverviewHeading(
                "Theme",
                detail: "Choose how QuickMail’s surfaces and contrast should look."
            )

            VStack(spacing: 10) {
                ForEach(AppThemeRegistry.all) { theme in
                    themeChoice(theme)
                }
            }
        }
        .modifier(SettingsPanelModifier())
    }

    private func themeChoice(_ theme: AppTheme) -> some View {
        let isSelected = theme.id == selectedTheme.id
        let previewPalette = theme.palette(for: colorScheme)
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)

        return Button {
            selectTheme(theme)
        } label: {
            HStack(spacing: 13) {
                canvasPreview(palette: previewPalette)

                VStack(alignment: .leading, spacing: 3) {
                    Text(theme.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(settingsPalette.primaryText)
                    Text(theme.detail)
                        .font(.footnote)
                        .foregroundStyle(settingsPalette.secondaryText)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 8)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.accentColor : settingsPalette.secondaryText.opacity(0.5))
                    .accessibilityHidden(true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
            .background(isSelected ? Color.accentColor.opacity(0.09) : settingsPalette.fill, in: shape)
            .overlay {
                shape.stroke(
                    isSelected ? Color.accentColor.opacity(0.85) : settingsPalette.separator,
                    lineWidth: isSelected ? 1.5 : 0.5
                )
            }
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(theme.title)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityHint(theme.detail)
    }

    private func canvasPreview(palette: AppThemePalette) -> some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        return ZStack {
            shape.fill(palette.grouped)

            VStack(alignment: .leading, spacing: 4) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(palette.raised)
                    .frame(height: 15)
                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(palette.primaryText.opacity(0.72))
                    .frame(width: 27, height: 3)
                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(palette.secondaryText.opacity(0.55))
                    .frame(width: 20, height: 2)
            }
            .padding(7)
        }
        .frame(width: 52, height: 46)
        .overlay { shape.stroke(palette.separator, lineWidth: 0.75) }
        .accessibilityHidden(true)
    }

    private func settingsOverviewHeading(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(QuickMailDesign.Palette.primaryText)
            Text(detail)
                .font(.footnote)
                .foregroundStyle(QuickMailDesign.Palette.secondaryText)
        }
    }

    private func settingsGroup<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(QuickMailDesign.Palette.secondaryText)
                .padding(.horizontal, 2)

            VStack(spacing: 0) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .modifier(SettingsPanelModifier(contentPadding: 0))
        }
    }

    private var settingsGroupDivider: some View {
        QuickMailRule()
            .padding(.leading, 58)
            .accessibilityHidden(true)
    }

    private var appearancePage: some View {
        settingsPage {
            appearanceOverview
        }
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var accountPage: some View {
        settingsPage {
            accountIdentitySummary
            accountSection
        }
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var sendingPage: some View {
        settingsPage {
            sendingAddressSection
            signatureSection
        }
        .navigationTitle("Composing")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                saveSignatureToolbarButton
            }
        }
    }

    private var privacyPage: some View {
        settingsPage {
            privacySection
            remoteImagesSection
        }
        .navigationTitle("Privacy & Security")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var devicesPage: some View {
        settingsPage {
            devicesSection
        }
        .navigationTitle("Connected Devices")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await model.load() }
    }

    private var connectionPage: some View {
        settingsPage(spacing: 24) {
            serverSection
            disconnectSection
            localDataSection
        }
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

    private func settingsPage<Content: View>(
        spacing: CGFloat = 24,
        @ViewBuilder content: () -> Content
    ) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: spacing) {
                content()
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 40)
            .frame(maxWidth: QuickMailDesign.contentMaxWidth)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .background(settingsPalette.grouped)
        .toolbarBackground(settingsPalette.paper, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    private var accountIdentitySummary: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 12) {
                    ParticipantMonogram(
                        name: displayName,
                        isEmphasized: true,
                        size: 58
                    )
                    accountIdentityText
                }
            } else {
                HStack(spacing: 16) {
                    ParticipantMonogram(
                        name: displayName,
                        isEmphasized: true,
                        size: 58
                    )
                    accountIdentityText
                    Spacer(minLength: 0)
                }
            }
        }
        .modifier(SettingsPanelModifier())
        .accessibilityElement(children: .combine)
    }

    private var accountIdentityText: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(displayName)
                .font(.title3.weight(.semibold))
                .foregroundStyle(QuickMailDesign.Palette.primaryText)
            Text(model.currentUser.email)
                .font(.subheadline)
                .foregroundStyle(QuickMailDesign.Palette.secondaryText)
                .textSelection(.enabled)
        }
    }

    private func settingsDestinationLabel(
        _ title: String,
        systemImage: String,
        detail: String? = nil
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.body)
                .foregroundStyle(Color.accentColor)
                .frame(width: 32, height: 32)
                .background(
                    Color.accentColor.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(QuickMailDesign.Palette.primaryText)

                if dynamicTypeSize.isAccessibilitySize, let detail {
                    Text(detail)
                        .font(.quickMailBody(15, relativeTo: .subheadline))
                        .foregroundStyle(QuickMailDesign.Palette.secondaryText)
                }
            }

            Spacer(minLength: 8)

            if !dynamicTypeSize.isAccessibilitySize, let detail {
                Text(detail)
                    .font(.quickMailBody(15, relativeTo: .subheadline))
                    .foregroundStyle(QuickMailDesign.Palette.secondaryText)
                    .lineLimit(1)
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(QuickMailDesign.Palette.secondaryText)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(minHeight: 56)
        .contentShape(Rectangle())
    }

    private func settingsPageSection<Content: View>(
        _ title: String,
        detail: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(QuickMailDesign.Palette.secondaryText)
                .padding(.horizontal, 2)

            VStack(spacing: 0) {
                content()
            }
            .modifier(SettingsPanelModifier(contentPadding: 0))

            if let detail {
                Text(detail)
                    .font(.quickMailBody(13, relativeTo: .footnote))
                    .foregroundStyle(QuickMailDesign.Palette.secondaryText)
                    .padding(.horizontal, 2)
            }
        }
    }

    private var settingsInsetDivider: some View {
        QuickMailRule()
            .padding(.leading, 16)
            .accessibilityHidden(true)
    }

    private func labeledValueRow(_ label: String, value: String) -> some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 4) {
                    labeledValueLabel(label)
                    labeledValue(value, alignment: .leading)
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 16) {
                    labeledValueLabel(label)
                    Spacer(minLength: 16)
                    labeledValue(value, alignment: .trailing)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func labeledValueLabel(_ label: String) -> some View {
        Text(label)
            .font(.body)
            .foregroundStyle(QuickMailDesign.Palette.primaryText)
    }

    private func labeledValue(_ value: String, alignment: TextAlignment) -> some View {
        Text(value)
            .font(.quickMailBody(15, relativeTo: .subheadline))
            .foregroundStyle(QuickMailDesign.Palette.secondaryText)
            .multilineTextAlignment(alignment)
            .textSelection(.enabled)
    }

    private func selectTheme(_ theme: AppTheme) {
        guard theme.id != selectedTheme.id else { return }
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            appThemeID = theme.id
        }
        AppFeedback.selection()
    }

    private var accountSection: some View {
        settingsPageSection(
            "Details",
            detail: "This app stays connected directly to your QuickMail server."
        ) {
            labeledValueRow("Name", value: displayName)

            settingsInsetDivider

            labeledValueRow("Email", value: model.currentUser.email)

            if let manageURL = model.manageWebURL {
                settingsInsetDivider

                Link(destination: manageURL) {
                    HStack(spacing: 12) {
                        Label("Manage Account on the Web", systemImage: "safari")
                            .font(.body)
                        Spacer(minLength: 8)
                        Image(systemName: "arrow.up.right")
                            .font(.caption.weight(.semibold))
                            .accessibilityHidden(true)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .accessibilityHint("Opens your QuickMail account settings in the browser")
            }
        }
    }

    private var serverSection: some View {
        settingsPageSection(
            "Connection",
            detail: "This device connects directly to your QuickMail server over HTTPS."
        ) {
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
                            .font(.quickMailBody(15, relativeTo: .subheadline))
                            .foregroundStyle(QuickMailDesign.Palette.secondaryText)
                            .textSelection(.enabled)

                        if let scheme = model.serverURL?.scheme?.uppercased() {
                            Label(scheme, systemImage: "lock.fill")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(QuickMailDesign.Palette.secondaryText)
                        }
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if model.isLoading {
                loadingRow("Loading server details")
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Label("Server details unavailable", systemImage: "server.rack")
                    .foregroundStyle(QuickMailDesign.Palette.secondaryText)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var sendingAddressSection: some View {
        settingsPageSection(
            "Sending",
            detail: model.addresses.count > 1
                ? "QuickMail preselects this address when you start a new message on this device."
                : "This is the only sending address currently available on your account."
        ) {
            if model.isLoading && model.addresses.isEmpty {
                loadingRow("Loading sending addresses")
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if model.addresses.isEmpty {
                Label("No sending addresses available", systemImage: "at.badge.minus")
                    .foregroundStyle(QuickMailDesign.Palette.secondaryText)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                if model.addresses.count == 1 {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text("Default Sender")
                        Spacer(minLength: 12)
                        Text(selectedAddressTitle)
                            .foregroundStyle(QuickMailDesign.Palette.secondaryText)
                            .multilineTextAlignment(.trailing)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Menu {
                        Picker("Default Sender", selection: $model.selectedAddressID) {
                            ForEach(model.addresses) { address in
                                Text(addressTitle(address))
                                    .tag(address.id)
                            }
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Text("Default Sender")
                                .foregroundStyle(QuickMailDesign.Palette.primaryText)

                            Spacer(minLength: 12)

                            Text(selectedAddressTitle)
                                .foregroundStyle(QuickMailDesign.Palette.secondaryText)
                                .lineLimit(1)

                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(QuickMailDesign.Palette.secondaryText)
                                .accessibilityHidden(true)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Chooses the address preselected for new messages")
                }
            }
        }
    }

    private var signatureSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Signature")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(QuickMailDesign.Palette.secondaryText)
                .padding(.horizontal, 2)

            Group {
                if model.isLoading && !model.hasLoadedSignature {
                    loadingRow("Loading signature")
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    TextField(
                        "Add a signature to new messages…",
                        text: $model.signatureDraft,
                        axis: .vertical
                    )
                    .textFieldStyle(.plain)
                    .lineLimit(2...7)
                    .padding(14)
                    .accessibilityLabel("Email signature")
                    .onChange(of: model.signatureDraft) { _, value in
                        if value.count > SettingsViewModel.signatureLimit {
                            model.signatureDraft = String(value.prefix(SettingsViewModel.signatureLimit))
                        }
                    }
                }
            }
            .modifier(SettingsPanelModifier(contentPadding: 0))

            VStack(alignment: .leading, spacing: 5) {
                signatureStatus
                Text("Added to sent mail unless the selected sending address has its own signature.")
                    .font(.quickMailBody(13, relativeTo: .footnote))
                    .foregroundStyle(QuickMailDesign.Palette.secondaryText)
            }
            .padding(.horizontal, 2)
        }
    }

    private var signatureStatus: some View {
        HStack(spacing: 12) {
            Text("\(model.signatureDraft.count) / \(SettingsViewModel.signatureLimit.formatted())")
                .font(.quickMailBody(13, relativeTo: .caption))
                .foregroundStyle(QuickMailDesign.Palette.secondaryText)
                .monospacedDigit()
                .contentTransition(.numericText())

            Spacer(minLength: 8)

            if model.signatureSaved {
                Label("Saved", systemImage: "checkmark")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(QuickMailDesign.Palette.secondaryText)
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
        .tint(Color.accentColor)
        .accessibilityHint(
            model.signatureHasChanges
                ? "Saves the signature to your account"
                : "No unsaved signature changes"
        )
    }

    private var devicesSection: some View {
        settingsPageSection(
            "Connected Devices",
            detail: "Revoke any device you no longer recognize or use."
        ) {
            if model.isLoading && model.devices.isEmpty {
                loadingRow("Loading connected devices")
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if model.devices.isEmpty {
                Label("No connected devices found", systemImage: "rectangle.stack.badge.minus")
                    .foregroundStyle(QuickMailDesign.Palette.secondaryText)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(model.devices) { device in
                    deviceRow(device)

                    if device.id != model.devices.last?.id {
                        QuickMailRule()
                            .padding(.leading, 60)
                            .accessibilityHidden(true)
                    }
                }
            }
        }
    }

    private func deviceRow(_ device: DeviceSession) -> some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 6) {
                    deviceIdentity(device)
                    HStack {
                        Spacer(minLength: 0)
                        deviceAccessory(device)
                    }
                }
            } else {
                HStack(spacing: 12) {
                    deviceIdentity(device)
                    Spacer(minLength: 8)
                    deviceAccessory(device)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func deviceIdentity(_ device: DeviceSession) -> some View {
        HStack(spacing: 12) {
            Image(systemName: model.symbolName(for: device))
                .font(.body.weight(.medium))
                .foregroundStyle(device.isCurrent ? QuickMailDesign.Palette.sage : QuickMailDesign.Palette.secondaryText)
                .frame(width: 32, height: 44, alignment: .center)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(model.displayName(for: device))
                    .font(.body.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)

                Text(model.deviceDetail(for: device))
                    .font(.quickMailBody(13, relativeTo: .caption))
                    .foregroundStyle(QuickMailDesign.Palette.secondaryText)
            }
            .accessibilityElement(children: .combine)
        }
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
                .foregroundStyle(QuickMailDesign.Palette.secondaryText)
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
        settingsPageSection(
            "Session",
            detail: "Revokes this session on your server and removes the account and cached mail from this device."
        ) {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Disconnect This Device")
                        .font(.body.weight(.medium))
                    Text("Revoke access and sign out")
                        .font(.quickMailBody(13, relativeTo: .caption))
                        .foregroundStyle(QuickMailDesign.Palette.secondaryText)
                }

                Button(role: .destructive) {
                    showingDisconnectConfirmation = true
                } label: {
                    disconnectButtonLabel("Disconnect")
                }
                .buttonStyle(SettingsDestructiveButtonStyle())
                .disabled(model.isDisconnecting)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
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
                    .font(.quickMailSemibold(15, relativeTo: .subheadline))
                    .frame(minHeight: 32)
            }
        }
    }

    private var localDataSection: some View {
        settingsPageSection(
            "Recovery",
            detail: "Use only when your server cannot be reached. You may still need to revoke this device on the web."
        ) {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Local App Data")
                        .font(.body.weight(.medium))
                    Text("Clear this device without contacting the server")
                        .font(.quickMailBody(13, relativeTo: .caption))
                        .foregroundStyle(QuickMailDesign.Palette.secondaryText)
                }

                Button(role: .destructive) {
                    showingLocalWipeConfirmation = true
                } label: {
                    disconnectButtonLabel("Remove Local Data")
                }
                .buttonStyle(SettingsDestructiveButtonStyle())
                .disabled(model.isDisconnecting)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var privacySection: some View {
        settingsPageSection(
            "Privacy",
            detail: "When enabled, QuickMail hides message content after you leave the app and asks for \(appLock.biometryName) or your device passcode when you return."
        ) {
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
                        .font(.quickMailBody(13, relativeTo: .caption))
                        .foregroundStyle(QuickMailDesign.Palette.secondaryText)
                }
            }
            .disabled(!appLock.isAvailable && !appLock.isEnabled)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(minHeight: 58)

            if let message = appLock.errorMessage {
                settingsInsetDivider

                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.quickMailBody(13, relativeTo: .caption))
                    .foregroundStyle(.red)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel("App Lock unavailable. \(message)")
            }
        }
    }

    private var remoteImagesSection: some View {
        settingsPageSection(
            "Email Images",
            detail: "Remote images can let senders know when and where you opened a message. When disabled, you can still show images for an individual email."
        ) {
            Toggle(isOn: $showRemoteImagesByDefault) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Show Email Images")
                    Text("Automatically load images from the internet")
                        .font(.quickMailBody(13, relativeTo: .caption))
                        .foregroundStyle(QuickMailDesign.Palette.secondaryText)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(minHeight: 58)
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

    private var selectedAddressTitle: String {
        guard let address = model.addresses.first(where: { $0.id == model.selectedAddressID })
                ?? model.addresses.first else {
            return "Unavailable"
        }
        return addressTitle(address)
    }

    private func loadingRow(_ title: String) -> some View {
        HStack(spacing: 10) {
            ProgressView()
            Text(title)
                .foregroundStyle(QuickMailDesign.Palette.secondaryText)
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

private struct SettingsPanelModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.appTheme) private var appTheme
    var contentPadding: CGFloat = 16

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        let palette = appTheme.palette(for: colorScheme)

        content
            .padding(contentPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                palette.raised,
                in: shape
            )
            .overlay {
                shape.stroke(palette.separator.opacity(0.55), lineWidth: 0.5)
            }
    }
}

private struct SettingsDestructiveButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let red = Color(uiColor: .systemRed)
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)

        configuration.label
            .foregroundStyle(red)
            .padding(.horizontal, 16)
            .frame(minHeight: 48)
            .background(
                red.opacity(0.08),
                in: shape
            )
            .overlay {
                shape.stroke(red.opacity(0.78), lineWidth: 1)
            }
            .opacity(isEnabled ? (configuration.isPressed ? 0.68 : 1) : 0.42)
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
        } catch is CancellationError {
            return
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
