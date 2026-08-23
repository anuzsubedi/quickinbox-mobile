import SwiftUI

struct AuthenticatedRootView: View {
    let api: QuickMailAPI
    let mailboxCache: MailboxCache
    let currentUser: User
    let onDisconnected: () -> Void

    @State private var selectedSection: AppSection = .mail
    @State private var selectedThread: ThreadSelection?
    @State private var composePresentation: ComposePresentation?
    @State private var mailboxGeneration = UUID()

    var body: some View {
        primaryLayout
        .sheet(item: $composePresentation) { presentation in
            ComposeView(api: api, mode: presentation.mode) { _ in
                refreshMailbox()
            }
        }
    }

    private var primaryLayout: some View {
        TabView(selection: $selectedSection) {
            mailboxView
                .tag(AppSection.mail)
                .tabItem { Label("Mail", systemImage: "tray.full") }

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

    private var mailboxView: some View {
        MailboxFeatureView(
            api: api,
            userID: currentUser.id,
            cache: mailboxCache,
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
