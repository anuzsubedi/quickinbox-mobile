import SwiftUI

struct AuthenticatedRootView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let api: QuickInboxAPI
    let mailboxCache: MailboxCache
    let currentUser: User
    let onDisconnected: (String?) -> Void

    @State private var selectedThread: ThreadSelection?
    @State private var compactPath: [ThreadSelection] = []
    @State private var composePresentation: ComposePresentation?
    @State private var isSettingsPresented = false
    @State private var mailboxRefreshToken = UUID()

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                regularLayout
            } else {
                compactLayout
            }
        }
        .sheet(isPresented: $isSettingsPresented, onDismiss: {
            AppFeedback.play(.navigationExited)
        }) {
            NavigationStack {
                SettingsView(
                    api: api,
                    currentUser: currentUser,
                    onDisconnected: onDisconnected
                )
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            isSettingsPresented = false
                        } label: {
                            Image(systemName: "xmark")
                        }
                        .accessibilityLabel("Close Settings")
                    }
                }
            }
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $composePresentation) { presentation in
            ComposeView(api: api, mode: presentation.mode) { _ in
                refreshMailbox()
            }
        }
        .onChange(of: horizontalSizeClass) { _, sizeClass in
            adaptSelection(to: sizeClass)
        }
        .onChange(of: compactPath) { oldPath, path in
            if horizontalSizeClass != .regular, path.isEmpty {
                if !oldPath.isEmpty {
                    AppFeedback.play(.navigationExited)
                }
                selectedThread = nil
            }
        }
    }

    private var compactLayout: some View {
        NavigationStack(path: $compactPath) {
            mailboxView
                .navigationDestination(for: ThreadSelection.self) { selection in
                    ThreadScene(
                        api: api,
                        selection: selection,
                        onMailboxMutation: refreshMailbox,
                        onExit: exitRegularThread
                    )
                }
        }
    }

    private var regularLayout: some View {
        NavigationSplitView {
            mailboxView
                .navigationSplitViewColumnWidth(min: 320, ideal: 390, max: 480)
        } detail: {
            NavigationStack {
                if let selectedThread {
                    ThreadScene(
                        api: api,
                        selection: selectedThread,
                        onMailboxMutation: refreshMailbox,
                        onExit: exitRegularThread
                    )
                    .id(selectedThread.id)
                } else {
                    conversationPlaceholder
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
    }

    private var mailboxView: some View {
        MailboxFeatureView(
            api: api,
            userID: currentUser.id,
            cache: mailboxCache,
            refreshToken: mailboxRefreshToken,
            onCompose: { draftID in
                composePresentation = ComposePresentation(
                    mode: draftID.map(ComposeMode.draft(draftID:)) ?? .newMessage
                )
            },
            onOpenSettings: {
                AppFeedback.play(.navigationEntered)
                isSettingsPresented = true
            },
            onMailboxChanged: resetMailboxSelection,
            onSelectThread: openThread
        )
    }

    private var conversationPlaceholder: some View {
        VStack(spacing: 18) {
            AnimatedMailGlyph()
            Text("No Conversation Selected")
                .font(.title3.weight(.semibold))
                .foregroundStyle(QuickInboxDesign.Palette.primaryText)
            Text("Select a conversation from the sidebar to read it here.")
                .font(.subheadline)
                .foregroundStyle(QuickInboxDesign.Palette.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .quickInboxCard()
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(QuickInboxDesign.Palette.paperGrouped)
    }

    private func openThread(_ summary: ThreadSummary) {
        AppFeedback.play(.navigationEntered)
        let selection = ThreadSelection(summary: summary)
        selectedThread = selection

        if horizontalSizeClass != .regular {
            compactPath.append(selection)
        }
    }

    private func refreshMailbox() {
        mailboxRefreshToken = UUID()
    }

    private func resetMailboxSelection() {
        selectedThread = nil
        compactPath.removeAll()
    }

    private func adaptSelection(to sizeClass: UserInterfaceSizeClass?) {
        if sizeClass == .regular {
            compactPath.removeAll()
        } else if let selectedThread, compactPath.isEmpty {
            compactPath = [selectedThread]
        }
    }

    private func exitRegularThread() {
        if horizontalSizeClass == .regular {
            AppFeedback.play(.navigationExited)
            selectedThread = nil
        }
    }
}

private struct ThreadSelection: Identifiable, Hashable {
    let summary: ThreadSummary

    var id: String { summary.id }

    static func == (lhs: ThreadSelection, rhs: ThreadSelection) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

private struct ComposePresentation: Identifiable {
    let id = UUID()
    let mode: ComposeMode
}

private struct ThreadScene: View {
    let api: QuickInboxAPI
    let selection: ThreadSelection
    let onMailboxMutation: () -> Void
    let onExit: () -> Void

    @State private var composePresentation: ComposePresentation?
    @State private var refreshToken = UUID()

    var body: some View {
        ThreadReaderView(
            api: api,
            threadID: selection.summary.id,
            summary: selection.summary,
            refreshToken: refreshToken,
            onReply: presentReply,
            onForward: presentForward,
            onMailboxMutation: onMailboxMutation,
            onExit: onExit
        )
        .sheet(item: $composePresentation) { presentation in
            ComposeView(api: api, mode: presentation.mode) { _ in
                refreshToken = UUID()
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

    private func presentForward(messages: [ThreadMessage]) {
        let baseSubject = selection.summary.subject
        let subject = baseSubject.lowercased().hasPrefix("fwd:")
            ? baseSubject
            : "Fwd: \(baseSubject)"

        let forwardedMessages = messages.map { message in
            let rawBody = message.bodyText?.trimmingCharacters(in: .whitespacesAndNewlines)
                ?? plainText(from: message.bodyHTML)
            let body = QuotedTextParser.split(rawBody).message
            let date = message.createdAt.formatted(
                .dateTime.month(.wide).day().year().hour().minute()
            )
            let ccLine = message.ccAddress.flatMap { $0.isEmpty ? nil : "\nCc: \($0)" } ?? ""

            return """
            From: \(message.fromAddress)
            Date: \(date)
            Subject: \(message.subject.isEmpty ? baseSubject : message.subject)
            To: \(message.toAddress)\(ccLine)

            \(body)
            """
        }
        .joined(separator: "\n\n------------------------------\n\n")

        let forwardedBody = """


        ---------- Forwarded conversation ----------
        \(forwardedMessages)
        """

        composePresentation = ComposePresentation(
            mode: .forward(subject: subject, body: forwardedBody)
        )
    }

    private func plainText(from html: String?) -> String {
        guard let html else { return "" }
        return html
            .replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: .regularExpression)
            .replacingOccurrences(of: "</p>", with: "\n\n", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
