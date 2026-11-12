import SwiftUI
import FCDomain
import FCUI

/// Which multisig group the co-sign sheet is open for. A wrapper
/// rather than a bare `String?` so `.sheet(item:)` can key on it.
private struct SigningGroup: Identifiable {
    let fid: String
    var id: String { fid }
}

/// The unlocked landing screen, laid out as Freer for Android lays out
/// its `HomeActivity`: the app's name and the header buttons, the live
/// FID's card, the getting-started checklist while a step is left, and
/// under them a three-column grid of tiles — one per thing the app does.
///
/// **This screen is also the overview.** The Mac has a pane that says
/// what is waiting; Android says it on the grid itself, as a count on the
/// corner of the tile that holds it, and so does this: unread chats and
/// Cmail, cashes not yet looked at, and a line above the grid for a DOCK
/// that has stopped delivering until it is paid.
///
/// **A tile pushes a pane.** Each pane is the Mac app's, where the same
/// list is a sidebar; a phone has no room for a sidebar beside its
/// detail, so the grid is the sidebar and the navigation stack is the
/// detail column. ``AppState/selectedPane`` stays the single place that
/// says which pane is open, so everything that already steers by it —
/// the checklist opening Chat on its Squares tab, an identity switch
/// falling back from a pane the new identity cannot use — steers this
/// screen too, unchanged. Its `.overview` is this grid.
struct HomeView: View {
    @Environment(AppState.self) private var appState

    /// The pane on screen, if any. Empty is the grid itself.
    @State private var path: [WalletPane] = []

    @State private var showQrTool = false
    @State private var showReceive = false
    @State private var showPersonMenu = false
    @State private var showAddWatched = false
    @State private var showSetMaster = false
    @State private var showAddServants = false
    @State private var showCreateMultisig = false
    @State private var showAddMultisig = false
    @State private var showBackupPrikey = false
    /// The backup sheet asked for the master carve. Two sheets hang off this
    /// same view, so the second is opened from the first's `onDismiss` —
    /// asking for it while the backup sheet is still on screen drops it.
    @State private var setMasterAfterBackup = false
    /// The same hand-over, from the person menu to whichever sheet one of
    /// its rows asked for: on a phone the menu is itself a sheet, and the
    /// next one can only go up once it has come down.
    @State private var afterPersonMenu: (() -> Void)?
    /// The group a co-sign sheet is open for. Identifiable-by-value so
    /// the sheet is rebuilt when the group changes.
    @State private var signingGroup: SigningGroup?
    /// One-line result of the last person-menu action, shown as a
    /// banner. The sheet that started it is gone by the time the
    /// answer arrives, so it has nowhere else to land.
    @State private var identityNote: String?

    /// What the tiles' corners count. Read from local stores, so it is
    /// right offline and costs nothing to read again.
    @State private var badges = HomeBadges()
    /// The DOCK whose top-up sheet is open.
    @State private var toppingUp: DockRegistry.Unpaid?

    var body: some View {
        if let session = appState.activeSession {
            content(for: session)
        } else {
            // Defensive: shouldn't happen — the router only shows
            // this view when activeSession is non-nil.
            VStack {
                Text("No active session.")
                Button("Back to vault") { appState.lockAll() }
            }
            .padding()
        }
    }

    // MARK: - shell

    @ViewBuilder
    private func content(for session: ActiveSession) -> some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    PaneHeader(session: session)
                    GettingStartedCard(session: session)
                    dockNotices
                    grid(for: session)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            // The title row stays put while the grid scrolls under it: with
            // the navigation bar hidden, nothing else would keep the tiles
            // from sliding up behind the clock.
            .safeAreaInset(edge: .top, spacing: 0) {
                header(for: session)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 4)
                    .background(.bar)
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: WalletPane.self) { pane in
                detail(pane, for: session)
                    // Rebuild the pane when the live FID switches so it
                    // refreshes for the new identity (onAppear re-runs) —
                    // the analogue of Android's post-switch
                    // `refreshCidInfoAsync`.
                    .id(appState.liveFid)
                    .environment(\.paneIdentityHidden, true)
                    .navigationTitle(title(of: pane))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        // The title at the left end, as Android's toolbar
                        // has it; the centre, where iOS would put it, is
                        // left empty.
                        ToolbarItem(placement: .topBarLeading) {
                            Text(title(of: pane))
                                .font(.title3.weight(.semibold))
                                .lineLimit(1)
                                // Its own width, whatever the bar would
                                // rather give it: the identity chip is
                                // the one that gives way.
                                .fixedSize()
                                .accessibilityAddTraits(.isHeader)
                        }
                        .plainToolbarItem()
                        ToolbarItem(placement: .principal) { Text("") }
                        ToolbarItem(placement: .topBarTrailing) {
                            LiveIdentityChip(session: session) { path = [] }
                        }
                        .plainToolbarItem()
                    }
            }
        }
        .safeAreaInset(edge: .bottom) { identityNoteBanner }
        // Something other than a tile chose a pane.
        .onChange(of: appState.selectedPane) { _, pane in
            let wanted: [WalletPane] = pane == .overview ? [] : [pane]
            if path != wanted { path = wanted }
        }
        // Back to the grid. Said to the app state too, so that tapping
        // the same tile again is a change it can see.
        .onChange(of: path) { was, now in
            if now.isEmpty, appState.selectedPane != .overview {
                appState.selectedPane = .overview
            }
            // Going in, the cashes in the cache are about to be shown;
            // coming out, so are the ones the pane fetched meanwhile.
            if was == [.cash] || now == [.cash] {
                SeenCashes.markAllSeen(for: session)
            }
            if now.isEmpty {
                Task { await refresh(session) }
            }
        }
        // On arrival, and again for each identity lived as.
        .task(id: appState.liveFid) { await refresh(session) }
        // A background collect filed something.
        .onChange(of: appState.inboxRevision) { _, _ in reloadBadges(session) }
        .sheet(item: $toppingUp) { unpaid in
            DockTopUpSheet(session: session, unpaid: unpaid, onClose: { toppingUp = nil })
        }
        .sheet(isPresented: $showQrTool) {
            QrToolSheet { showQrTool = false }
        }
        .sheet(isPresented: $showReceive) {
            QrDisplaySheet(title: String(localized: "Receive"), content: session.liveFid) { showReceive = false }
        }
        .sheet(isPresented: $showPersonMenu, onDismiss: {
            let next = afterPersonMenu
            afterPersonMenu = nil
            next?()
        }) {
            personMenu(for: session)
        }
        .sheet(isPresented: $showAddWatched) {
            AddWatchedFidSheet(session: session) { _ in
                showAddWatched = false
            } onCancel: {
                showAddWatched = false
            }
        }
        .sheet(isPresented: $showSetMaster) {
            SetMasterSheet(session: session) { txid in
                showSetMaster = false
                appState.bumpIdentityRevision()
                Task { await appState.refreshLiveFidInfo() }
                identityNote = String(localized: "Master carve broadcast — \(txid.elidingMiddle(head: 8, tail: 8)). It takes effect when the block confirms.")
            } onCancel: {
                showSetMaster = false
            }
        }
        .sheet(isPresented: $showCreateMultisig) {
            CreateMultisigSheet(session: session) { info in
                showCreateMultisig = false
                appState.bumpIdentityRevision()
                identityNote = String(localized: "Created \(info.fid.elidingMiddle(head: 8, tail: 8)). Give every member its redeem script — without it the group's coins cannot be moved.")
            } onCancel: {
                showCreateMultisig = false
            }
        }
        .sheet(isPresented: $showAddMultisig) {
            AddMultisigSheet(session: session) { count in
                showAddMultisig = false
                appState.bumpIdentityRevision()
                identityNote = count == 1
                    ? String(localized: "Added 1 multisig group.")
                    : String(localized: "Added \(count) multisig groups.")
            } onCancel: {
                showAddMultisig = false
            }
        }
        .sheet(item: $signingGroup) { target in
            SignMultisigTxSheet(session: session, groupFid: target.fid) { txid in
                signingGroup = nil
                identityNote = String(localized: "Broadcast \(txid.elidingMiddle(head: 8, tail: 8)).")
            } onCancel: {
                signingGroup = nil
            }
        }
        .sheet(isPresented: $showAddServants) {
            AddServantsSheet(session: session) { count in
                showAddServants = false
                appState.bumpIdentityRevision()
                identityNote = count == 1
                    ? String(localized: "Added 1 servant.")
                    : String(localized: "Added \(count) servants.")
            } onCancel: {
                showAddServants = false
            }
        }
        .onChange(of: appState.setMasterRequested) { _, requested in
            if requested {
                showSetMaster = true
                appState.consumeSetMasterRequest()
            }
        }
        .onChange(of: appState.backupPrikeyRequested) { _, requested in
            if requested {
                showBackupPrikey = true
                appState.consumeBackupPrikeyRequest()
            }
        }
        .sheet(isPresented: $showBackupPrikey, onDismiss: {
            if setMasterAfterBackup {
                setMasterAfterBackup = false
                appState.openSetMaster()
            }
        }) {
            BackupPrikeySheet(session: session) {
                showBackupPrikey = false
                appState.markPrikeyBackedUp()
                identityNote = String(localized: "Backup recorded. The reminder stops — the copy itself is yours to keep safe.")
            } onLater: {
                showBackupPrikey = false
            } onSetMaster: {
                // Nothing is recorded as backed up: the master is only a
                // backup once the chain confirms the carve, and the checklist
                // reads that from the record itself.
                setMasterAfterBackup = true
                showBackupPrikey = false
            }
        }
        // One details page for every FID a pane draws. The panes and
        // the FID bar reach it through `@Environment(\.inspectFid)`;
        // sheets that show FIDs of their own install their own host,
        // because a sheet cannot present a second sheet from here.
        .fidDetailsHost(session: session)
    }

    // MARK: - header

    /// Android's title row: the name on the left, the app-wide buttons on
    /// the right. They sit here rather than in a navigation bar because
    /// the grid is the app's front door, not a page with a title.
    private func header(for session: ActiveSession) -> some View {
        HStack(spacing: 4) {
            Text("Freer")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(Color.accentColor)
            Spacer()
            headerButton("qrcode.viewfinder", label: String(localized: "QR — scan or make QR codes")) {
                showQrTool = true
            }
            settingsMenu
            Button {
                showPersonMenu = true
            } label: {
                FidAvatarView(fid: session.liveFid, size: 28)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(Text("Identity — switch the live FID"))
            headerButton("lock.fill", label: String(localized: "Lock vault")) {
                appState.lockAll()
            }
        }
        .padding(.top, 8)
    }

    private func headerButton(_ systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 20))
                .frame(width: 44, height: 44)
        }
        .foregroundStyle(.secondary)
        .accessibilityLabel(label)
    }

    /// Android's settings menu: one row per settings screen, then the
    /// two screens about the app's own business that are not worth a
    /// tile — who is asking for a first FCH, and what the app has logged.
    private var settingsMenu: some View {
        Menu {
            Section {
                ForEach(SettingsPage.allCases) { page in
                    Button {
                        appState.openSettings(page)
                    } label: {
                        Label(page.title, systemImage: page.systemImage)
                    }
                }
            }
            Section {
                Button {
                    appState.openBackupPrikey()
                } label: {
                    Label("Back up prikey…", systemImage: "key.viewfinder")
                }
            }
            Section {
                Button {
                    appState.openFirstFchBoard()
                } label: {
                    // Counted only for an identity that asked to be told.
                    let waiting = appState.newcomersWaiting
                    Label(
                        waiting > 0
                            ? String(localized: "First FCH") + " (\(waiting))"
                            : String(localized: "First FCH"),
                        systemImage: WalletPane.helpBeginners.systemImage
                    )
                }
                Button {
                    appState.selectedPane = .logs
                } label: {
                    Label(WalletPane.logs.title, systemImage: WalletPane.logs.systemImage)
                }
            }
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 20))
                .frame(width: 44, height: 44)
                .overlay(alignment: .topTrailing) {
                    CountBadge(count: appState.newcomersWaiting)
                        .offset(x: -2, y: 4)
                }
        }
        .foregroundStyle(.secondary)
        .accessibilityLabel(Text("Settings"))
    }

    /// A pane's name in its title bar. Settings is five pages behind one
    /// pane, and each is titled as the menu named it.
    private func title(of pane: WalletPane) -> String {
        pane == .settings ? appState.settingsPage.title : pane.title
    }

    /// The person menu — who am I living as, and every identity role I
    /// can switch to (Android's `personView`).
    ///
    /// Each of its rows that opens a form closes the menu first and
    /// leaves the form to ``afterPersonMenu``: two sheets cannot be on
    /// their way up and down at once.
    private func personMenu(for session: ActiveSession) -> some View {
        func then(_ open: @escaping () -> Void) {
            afterPersonMenu = open
            showPersonMenu = false
        }
        return PersonMenuView(session: session) {
            then { showAddWatched = true }
        } onSetMaster: {
            then { showSetMaster = true }
        } onAddServants: {
            then { showAddServants = true }
        } onCreateMultisig: {
            then { showCreateMultisig = true }
        } onAddMultisig: {
            then { showAddMultisig = true }
        } onSignMultisig: { fid in
            then { signingGroup = SigningGroup(fid: fid) }
        } onClose: {
            showPersonMenu = false
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - grid

    private static let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    private func grid(for session: ActiveSession) -> some View {
        let canSign = session.canSign
        return LazyVGrid(columns: Self.columns, spacing: 8) {
            ForEach(HomeTile.all) { tile in
                let closedReason = tile.closedReason(canSign: canSign)
                // A shut pane counts nothing: the number would be an
                // invitation to open what cannot be opened.
                let count = closedReason == nil ? badges.count(for: tile) : 0
                Button {
                    if let closedReason {
                        identityNote = closedReason
                    } else {
                        open(tile)
                    }
                } label: {
                    VStack(spacing: 8) {
                        // The lock replaces the tile's own glyph rather
                        // than sitting beside it: the one fact worth
                        // reading here is that the pane is shut.
                        Image(systemName: closedReason == nil ? tile.systemImage : "lock")
                            .font(.system(size: 26))
                            .frame(height: 32)
                            .overlay(alignment: .topTrailing) {
                                CountBadge(count: count)
                                    .offset(x: 16, y: -6)
                            }
                        Text(tile.title)
                            .font(.footnote)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                // Dimmed, not removed: a grid that reflows when you
                // switch identity reads as a bug.
                .foregroundStyle(closedReason == nil ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary))
                .accessibilityHint(closedReason ?? "")
                // The tile keeps its name, for VoiceOver and for the UI
                // tests that find it by one; the count is its value.
                .accessibilityValue(count > 0 ? String(localized: "\(String(count)) new") : "")
            }
        }
    }

    // MARK: - what is waiting

    /// DOCKs that stopped handing messages over until their balance is
    /// topped up. Above the grid rather than on a tile: it is the one
    /// thing here that stops the other counts from arriving at all.
    ///
    /// A paid top-up keeps its line, turned blue, until the server serves
    /// again: taking it away at Pay would read as fixed before anything
    /// was credited, and an orange "Top up" still showing would invite
    /// paying twice.
    @ViewBuilder
    private var dockNotices: some View {
        ForEach(appState.unpaidDocks) { unpaid in
            let host = URLComponents(string: unpaid.dockUrl)?.host ?? unpaid.dockUrl
            let look: (title: String, symbol: String, tint: Color, detail: String) = {
                switch unpaid.stage() {
                case .needsPayment:
                    return (String(localized: "Top up \(host)"),
                            "creditcard.trianglebadge.exclamationmark", .orange,
                            String(localized: "\(unpaid.dockUrl) stopped handing over messages: \(unpaid.message). Click to top up your balance there."))
                case .confirming:
                    return (String(localized: "Top-up confirming: \(host)"),
                            "hourglass", .blue,
                            String(localized: "Paid. Messages from \(unpaid.dockUrl) resume once a block confirms the payment and the server credits it. Click for the txid."))
                case .lapsed:
                    return (String(localized: "Top-up not credited: \(host)"),
                            "exclamationmark.arrow.circlepath", .orange,
                            String(localized: "A top-up to \(unpaid.dockUrl) was sent over half an hour ago and the server still refuses. Click to check the txid or pay again."))
                }
            }()
            Button {
                toppingUp = unpaid
            } label: {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: look.symbol)
                        .font(.title3)
                        .foregroundStyle(look.tint)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(look.title).font(.callout.weight(.semibold))
                        Text(look.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(look.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                .contentShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
    }

    private func reloadBadges(_ session: ActiveSession) {
        var now = HomeBadges()
        now.cash = SeenCashes.newCount(for: session)
        now.mail = (try? session.mails.unreadCount()) ?? 0
        for style in ChatModeStyle.all {
            now.unread[style.mode] = (try? session.conversations.unread(type: style.mode)) ?? 0
            // Invitations and agreements waiting on an answer are not
            // messages and raise no unread count; without them here one
            // that arrives in the background shows nowhere.
            now.awaiting[style.mode] = session.awaitingAnswer(type: style.mode)
        }
        if now != badges { badges = now }
    }

    /// The counts as the stores have them, then again once the servers
    /// have been asked. Nothing here reports a failure: the last known
    /// numbers stay, and the pane behind each tile says what went wrong.
    private func refresh(_ session: ActiveSession) async {
        reloadBadges(session)
        // Coins that arrived since the cache was written are what the
        // Cash badge counts, and what the card's balance is waiting for.
        _ = try? await session.wallet.refreshCashes(forFid: session.liveFid)
        await appState.refreshLiveFidInfo()
        // Throttled in the session: one query a minute, however often
        // this screen comes back.
        await session.refreshTeamAnswers()
        reloadBadges(session)
    }

    private func open(_ tile: HomeTile) {
        switch tile.target {
        case .pane(let pane):
            appState.selectedPane = pane
        case .chat(let mode):
            // A team's count that is all offers is cleared by answering
            // them, not by looking at the list, so the tile goes where
            // the answering happens.
            if mode == .team, badges.unread[.team, default: 0] == 0, badges.awaiting[.team, default: 0] > 0 {
                appState.openTeamOffers()
            } else {
                appState.openChat(mode: mode)
            }
        case .pay:
            appState.sendMode = .send
            appState.selectedPane = .send
        case .receive:
            showReceive = true
        }
    }

    // MARK: - panes

    @ViewBuilder
    private func detail(_ pane: WalletPane, for session: ActiveSession) -> some View {
        switch pane {
        case .overview:
            // The grid itself; never pushed.
            EmptyView()
        case .send:
            SendView(session: session)
        case .cash:
            CashView(session: session)
        case .transactions:
            TransactionsView(session: session)
        case .proofs:
            ProofsView(session: session)
        case .tokens:
            TokensView(session: session)
        case .contacts:
            ContactsView(session: session)
        case .chat:
            ChatView(session: session)
        case .mail:
            MailView(session: session)
        case .news:
            NewsView(session: session)
        case .helpBeginners:
            FirstFchBoardView(session: session)
        case .files:
            FilesView(session: session)
        case .secrets:
            SecretsView(session: session)
        case .publishText:
            PublishTextView(session: session)
        case .publishStatement:
            PublishStatementView(session: session)
        case .publishImage:
            PublishMediaView(session: session, kind: .image)
        case .publishSound:
            PublishMediaView(session: session, kind: .sound)
        case .publishVideo:
            PublishMediaView(session: session, kind: .video)
        case .protocols:
            ProtocolsView(session: session)
        case .services:
            ServicesView(session: session)
        case .codes:
            CodesView(session: session)
        case .apps:
            AppsView(session: session)
        case .crypto:
            ToolsView(session: session)
        case .convert:
            ConvertView(session: session)
        case .logs:
            SystemMessagesView(session: session)
        case .settings:
            SettingsView(session: session, page: appState.settingsPage)
        }
    }

    @ViewBuilder
    private var identityNoteBanner: some View {
        if let identityNote {
            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                CopyableText(identityNote, font: .callout)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                Button {
                    self.identityNote = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.regularMaterial)
        }
    }
}

// MARK: - badges

/// What is waiting behind the tiles that can have something waiting.
struct HomeBadges: Equatable {
    /// Cashes the Cash pane has not shown yet.
    var cash = 0
    var mail = 0
    var unread: [ImType: Int] = [:]
    /// Invitations and agreements that want an answer.
    var awaiting: [ImType: Int] = [:]

    func count(for tile: HomeTile) -> Int {
        switch tile.target {
        case .pane(.cash): return cash
        case .pane(.mail): return mail
        case .chat(let mode): return unread[mode, default: 0] + awaiting[mode, default: 0]
        case .pane, .pay, .receive: return 0
        }
    }
}

/// Android's red count on a tile's corner. Nothing at zero.
struct CountBadge: View {
    let count: Int

    var body: some View {
        if count > 0 {
            Text(verbatim: count > 99 ? "99+" : String(count))
                .font(.caption2.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(.white)
                .padding(.horizontal, 5)
                .frame(minWidth: 18, minHeight: 18)
                .background(Color.red, in: Capsule())
                .fixedSize()
                .accessibilityHidden(true)
        }
    }
}

// MARK: - tiles

/// One square of the home grid.
///
/// **The order is Android's**, row for row, so someone who knows where
/// Cmail is on their phone finds it in the same place here. Where Android
/// has a tile this app has no screen for yet (TOTP, Todo, Carve), the
/// slot goes to the nearest thing it does have; the tiles Android lacks
/// follow at the end. Logs and First FCH are in the settings menu, where
/// Android has them.
struct HomeTile: Identifiable {
    enum Target {
        case pane(WalletPane)
        /// The Chat pane, on one of its four tabs. Android gives each
        /// its own tile.
        case chat(ImType)
        /// The Send pane, on its plain Send tab.
        case pay
        /// The live FID as a QR code.
        case receive
    }

    let title: String
    let systemImage: String
    let target: Target

    /// The image is what tells tiles apart: titles change with the language.
    var id: String { systemImage + "|" + title }

    /// Why this tile cannot be opened by the live identity, if it cannot.
    func closedReason(canSign: Bool) -> String? {
        guard !canSign else { return nil }
        switch target {
        case .pane(let pane): return pane.needsKey ? pane.closedReason : nil
        case .chat: return WalletPane.chat.closedReason
        case .pay, .receive: return nil
        }
    }

    private static func pane(_ pane: WalletPane, _ title: String? = nil) -> HomeTile {
        HomeTile(title: title ?? pane.title, systemImage: pane.systemImage, target: .pane(pane))
    }

    static let all: [HomeTile] = [
        pane(.news), pane(.convert, String(localized: "Convert")), pane(.crypto, String(localized: "Tools")),
        pane(.protocols, String(localized: "Protocol")), pane(.services, String(localized: "Service")), pane(.codes),
        pane(.proofs, String(localized: "Proof")), pane(.tokens, String(localized: "Token")), pane(.apps, String(localized: "APP")),
        pane(.secrets, String(localized: "Secret")), pane(.files), pane(.transactions, String(localized: "TX")),
        pane(.cash),
        HomeTile(title: String(localized: "Receive"), systemImage: "qrcode", target: .receive),
        HomeTile(title: String(localized: "Pay"), systemImage: "paperplane", target: .pay),
        HomeTile(title: String(localized: "Square"), systemImage: "megaphone", target: .chat(.square)),
        HomeTile(title: String(localized: "Team"), systemImage: "person.3", target: .chat(.team)),
        HomeTile(title: String(localized: "Room"), systemImage: "rectangle.3.group.bubble", target: .chat(.room)),
        pane(.contacts, String(localized: "Contact")), pane(.mail),
        HomeTile(title: String(localized: "Talk"), systemImage: "bubble.left.and.bubble.right", target: .chat(.p2p)),
        pane(.publishImage), pane(.publishText), pane(.publishStatement),
        pane(.publishSound), pane(.publishVideo),
    ]
}
