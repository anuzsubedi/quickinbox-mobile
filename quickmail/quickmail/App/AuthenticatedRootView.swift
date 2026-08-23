import SwiftUI

struct AuthenticatedRootView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let api: QuickMailAPI
    let currentUser: User
    let onDisconnected: () -> Void

    @State private var selectedSection: AppSection = .mail
    @State private var selectedThread: ThreadSelection?
    @State private var composePresentation: ComposePresentation?
    @State private var mailboxGeneration = UUID()

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                regularLayout
            } else {
                compactLayout
            }
        }
        .sheet(item: $composePresentation) { presentation in
            ComposeView(api: api, mode: presentation.mode) { _ in
                refreshMailbox()
            }
        }
    }

    private var compactLayout: some View {
        TabView(selection: $selectedSection) {
            mailboxView
                .tag(AppSection.mail)
                .tabItem { Label("Mail", systemImage: "envelope") }

            NavigationStack {
                SettingsView(
                    api: api,
                    currentUser: currentUser,
                    onDisconnected: onDisconnected
                )
            }
            .tag(AppSection.settings)
            .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .sheet(item: $selectedThread) { selection in
            NavigationStack {
                ThreadScene(
                    api: api,
                    selection: selection,
                    onMailboxMutation: refreshAndClearSelection
                )
            }
        }
    }

    private var regularLayout: some View {
        NavigationSplitView {
            List(selection: Binding<AppSection?>(
                get: { selectedSection },
                set: { if let section = $0 { selectedSection = section } }
            )) {
                Label("Mail", systemImage: "envelope")
                    .tag(AppSection.mail)
                Label("Settings", systemImage: "gearshape")
                    .tag(AppSection.settings)
            }
            .navigationTitle("QuickMail")
        } content: {
            switch selectedSection {
            case .mail:
                mailboxView
                    .environment(\.horizontalSizeClass, .compact)
            case .settings:
                AccountSummaryView(user: currentUser)
            }
        } detail: {
            switch selectedSection {
            case .mail:
                if let selectedThread {
                    NavigationStack {
                        ThreadScene(
                            api: api,
                            selection: selectedThread,
                            onMailboxMutation: refreshAndClearSelection
                        )
                    }
                    .id(selectedThread.id)
                } else {
                    ContentUnavailableView(
                        "Select a Conversation",
                        systemImage: "envelope.open",
                        description: Text("Choose a conversation from your mailbox to read it.")
                    )
                }
            case .settings:
                NavigationStack {
                    SettingsView(
                        api: api,
                        currentUser: currentUser,
                        onDisconnected: onDisconnected
                    )
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
    }

    private var mailboxView: some View {
        MailboxFeatureView(
            api: api,
            onCompose: { _ in
                composePresentation = ComposePresentation(mode: .newMessage)
            },
            onSelectThread: { summary in
                selectedThread = ThreadSelection(summary: summary)
            }
        )
        .id(mailboxGeneration)
    }

    private func refreshMailbox() {
        mailboxGeneration = UUID()
    }

    private func refreshAndClearSelection() {
        refreshMailbox()
        selectedThread = nil
    }
}

private enum AppSection: Hashable {
    case mail
    case settings
}

private struct ThreadSelection: Identifiable {
    let id = UUID()
    let summary: ThreadSummary
}

private struct ComposePresentation: Identifiable {
    let id = UUID()
    let mode: ComposeMode
}

private struct ThreadScene: View {
    let api: QuickMailAPI
    let selection: ThreadSelection
    let onMailboxMutation: () -> Void

    @State private var composePresentation: ComposePresentation?
    @State private var readerGeneration = UUID()

    var body: some View {
        ThreadReaderView(
            api: api,
            threadID: selection.summary.id,
            summary: selection.summary,
            onReply: presentReply,
            onMailboxMutation: onMailboxMutation
        )
        .id(readerGeneration)
        .sheet(item: $composePresentation) { presentation in
            ComposeView(api: api, mode: presentation.mode) { _ in
                readerGeneration = UUID()
                onMailboxMutation()
            }
        }
    }

    private func presentReply(messageID: String) {
        let recipient = selection.summary.participants
            .first(where: { !$0.selfParticipant })?
            .address ?? ""
        let subject = selection.summary.subject.hasPrefix("Re:")
            ? selection.summary.subject
            : "Re: \(selection.summary.subject)"

        composePresentation = ComposePresentation(
            mode: .reply(messageID: messageID, recipient: recipient, subject: subject)
        )
    }
}

private struct AccountSummaryView: View {
    let user: User

    var body: some View {
        List {
            Section("Account") {
                LabeledContent("Name", value: user.name)
                LabeledContent("Email", value: user.email)
            }
        }
        .navigationTitle("Settings")
    }
}
