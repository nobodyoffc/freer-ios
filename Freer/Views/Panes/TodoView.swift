import SwiftUI
import FCDomain
import FCUI

/// Everything waiting for this identity's answer, in one list — Android's
/// Todo (`PendingIssueActivity`).
///
/// The questions themselves are asked where they belong, as banners in
/// the Chat pane: a room invitation on the Room page, a consensus change
/// on the Team page. This page is the index of them, so one that arrived
/// while the user was elsewhere is found without visiting all four. Each
/// row goes to where it is answered: the sheet that answers it, or the
/// chat page whose banner does.
struct TodoView: View {

    let session: ActiveSession

    @Environment(AppState.self) private var appState

    @State private var items: [TodoItem] = []
    @State private var showRequests = false
    @State private var showTeamOffers = false
    @State private var showConsensus = false

    private var names: ChatNameBook { appState.chatNames }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Invitations, requests and agreements waiting for your answer.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if items.isEmpty {
                Spacer()
                Label("Nothing to do", systemImage: "checkmark.circle")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(items) { item in
                            Button { open(item) } label: { row(item) }
                                .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .bottomBar {
            Button { reload() } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
        }
        .onAppear(perform: reload)
        .task(id: items.compactMap(\.fid)) {
            names.resolve(items.compactMap(\.fid), session: session)
        }
        .sheet(isPresented: $showRequests, onDismiss: reload) {
            MessageRequestsSheet(
                session: session,
                names: names,
                onClose: { showRequests = false },
                onChanged: reload
            )
        }
        .sheet(isPresented: $showTeamOffers, onDismiss: reload) {
            TeamOffersSheet(
                session: session,
                onClose: { showTeamOffers = false },
                onChanged: reload
            )
        }
        .sheet(isPresented: $showConsensus, onDismiss: reload) {
            ConsensusSignatureSheet(
                session: session,
                onClose: { showConsensus = false },
                onChanged: reload
            )
        }
    }

    private func row(_ item: TodoItem) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: item.kind.systemImage)
                .foregroundStyle(item.kind.tint)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.kind.title)
                    .font(.caption.bold())
                    .foregroundStyle(item.kind.tint)
                Text(headline(item))
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                if let detail = item.detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(item.kind.tint.opacity(0.12)))
        .contentShape(Rectangle())
    }

    /// The row's sentence, with the person named as the chat pane would.
    private func headline(_ item: TodoItem) -> String {
        let who = item.fid.map { names.labelWithContact(for: $0) } ?? ""
        switch item.kind {
        case .messageRequest:
            return item.count == 1
                ? String(localized: "\(who) — 1 message")
                : String(localized: "\(who) — \(String(item.count)) messages")
        case .roomInvite:
            return String(localized: "\(item.name ?? String(localized: "A room")) — invitation from \(who)")
        case .teamInvite:
            return String(localized: "\(item.name ?? String(localized: "A team")) — invitation")
        case .teamTransfer:
            return String(localized: "\(item.name ?? String(localized: "A team")) — being handed to you")
        case .consensusChange:
            return String(localized: "\(item.name ?? String(localized: "A team")) changed its consensus")
        case .keyRotation:
            return String(localized: "\(item.name ?? String(localized: "A team")) — members left; rotate the key")
        case .historyRequest:
            return String(localized: "\(who) asks for a conversation's messages")
        case .historyFailed:
            return String(localized: "History from \(who) could not be added")
        case .mention:
            let group = item.name ?? String(localized: "A group")
            return item.count == 1
                ? String(localized: "\(group) — 1 message")
                : String(localized: "\(group) — \(String(item.count)) messages")
        }
    }

    private func open(_ item: TodoItem) {
        switch item.kind {
        case .messageRequest: showRequests = true
        case .teamInvite, .teamTransfer: showTeamOffers = true
        case .consensusChange: showConsensus = true
        case .roomInvite: appState.openChat(mode: .room)
        case .keyRotation: appState.openChat(mode: .team)
        case .historyRequest, .historyFailed: appState.openChat(mode: item.chatMode ?? .p2p)
        case .mention:
            if let conversation = item.conversation { appState.openChat(conversation: conversation) }
        }
    }

    private func reload() {
        items = TodoItem.all(in: session, myCid: names.cid(of: session.liveFid))
    }
}

/// One thing waiting for an answer: Android's `PendingIssue`.
struct TodoItem: Identifiable {
    enum Kind {
        case messageRequest, roomInvite, teamInvite, teamTransfer
        case consensusChange, keyRotation, historyRequest, historyFailed
        case mention

        var title: String {
            switch self {
            case .messageRequest:  return String(localized: "Message request")
            case .roomInvite:      return String(localized: "Room invitation")
            case .teamInvite:      return String(localized: "Team invitation")
            case .teamTransfer:    return String(localized: "Team handover")
            case .consensusChange: return String(localized: "Consensus change")
            case .keyRotation:     return String(localized: "Key rotation due")
            case .historyRequest:  return String(localized: "History request")
            case .historyFailed:   return String(localized: "History not added")
            case .mention:         return String(localized: "Mentioned you")
            }
        }

        var systemImage: String {
            switch self {
            case .messageRequest:  return "tray.full"
            case .roomInvite:      return "envelope.open"
            case .teamInvite, .teamTransfer: return "person.3.sequence"
            case .consensusChange: return "signature"
            case .keyRotation:     return "key.horizontal"
            case .historyRequest:  return "clock.arrow.circlepath"
            case .historyFailed:   return "exclamationmark.triangle"
            case .mention:         return "at"
            }
        }

        var tint: Color {
            switch self {
            case .roomInvite: return ChatModeStyle.of(.room).tint
            case .teamInvite, .teamTransfer: return ChatModeStyle.of(.team).tint
            case .historyRequest: return .accentColor
            case .mention: return .red
            case .messageRequest, .consensusChange, .keyRotation, .historyFailed: return .orange
            }
        }
    }

    let id: String
    let kind: Kind
    /// The person it is from, when there is one.
    var fid: String?
    /// The room's or team's name.
    var name: String?
    var detail: String?
    var count = 0
    /// The chat page whose banner answers it.
    var chatMode: ImType?
    /// The thread it is answered in, for one that is.
    var conversation: Conversation?

    /// Every open item, newest kinds of question first as Android lists
    /// them: people, then groups, then housekeeping.
    /// `myCid` is how a group's `@` names the live identity besides its FID.
    @MainActor
    static func all(in session: ActiveSession, myCid: String?) -> [TodoItem] {
        var items: [TodoItem] = []
        // Somebody waiting for an answer from you in a group: first, as
        // the most direct question there is.
        for mention in session.unreadMentions(myCid: myCid) {
            items.append(TodoItem(id: "mention|" + mention.id, kind: .mention,
                                  name: mention.groupName, count: mention.count,
                                  chatMode: mention.conversation.type, conversation: mention.conversation))
        }
        for request in (try? session.messageRequests.pending()) ?? [] {
            items.append(TodoItem(id: "request|" + request.fid, kind: .messageRequest,
                                  fid: request.fid, detail: request.lastPreview, count: request.count))
        }
        for invite in (try? session.roomInvites.all()) ?? [] {
            items.append(TodoItem(id: "room|" + invite.roomId, kind: .roomInvite,
                                  fid: invite.from, name: invite.name, chatMode: .room))
        }
        for offer in (try? session.teamOffers.waiting(fid: session.liveFid)) ?? [] {
            items.append(TodoItem(id: "offer|" + offer.teamId,
                                  kind: offer.kind == .invitation ? .teamInvite : .teamTransfer,
                                  name: offer.teamName ?? offer.teamId, chatMode: .team))
        }
        for change in (try? session.consensusSignatures.outstanding()) ?? [] {
            items.append(TodoItem(id: "consensus|" + change.id, kind: .consensusChange,
                                  name: change.teamName ?? change.id, chatMode: .team))
        }
        for rotation in (try? session.keyRotations.outstanding()) ?? [] {
            items.append(TodoItem(id: "rotation|" + rotation.id, kind: .keyRotation,
                                  name: rotation.teamName ?? rotation.id, chatMode: .team))
        }
        for ask in (try? session.historyShares.incoming()) ?? [] {
            items.append(TodoItem(id: "history|" + ask.id, kind: .historyRequest,
                                  fid: ask.from, chatMode: ask.type))
        }
        for share in ((try? session.historyShares.received()) ?? []).filter(\.waitsForRetry) {
            let type = ImType(rawValue: String(share.conversationId.prefix(while: { $0 != "_" })))
            items.append(TodoItem(id: "import|" + share.id, kind: .historyFailed,
                                  fid: share.from, detail: share.lastError, chatMode: type))
        }
        return items
    }

    /// The Todo tile's count.
    @MainActor
    static func count(in session: ActiveSession, myCid: String?) -> Int {
        all(in: session, myCid: myCid).count
    }
}
