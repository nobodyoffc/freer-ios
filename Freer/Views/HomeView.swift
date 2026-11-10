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
/// **A tile pushes a pane.** Each pane is the Mac app's, where the same
/// list is a sidebar; a phone has no room for a sidebar beside its
/// detail, so the grid is the sidebar and the navigation stack is the
/// detail column. ``AppState/selectedPane`` stays the single place that
/// says which pane is open, so everything that already steers by it —
/// an Overview tile opening Chat on its Teams tab, an identity switch
/// falling back from a pane the new identity cannot use — steers this
/// screen too, unchanged.
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
                    .navigationTitle(pane.title)
                    .navigationBarTitleDisplayMode(.inline)
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
        .onChange(of: path) { _, now in
            if now.isEmpty, appState.selectedPane != .overview {
                appState.selectedPane = .overview
            }
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
            headerButton("gearshape", label: String(localized: "Settings")) {
                appState.selectedPane = .settings
            }
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
            }
        }
    }

    private func open(_ tile: HomeTile) {
        switch tile.target {
        case .pane(let pane):
            if pane == .overview {
                // `selectedPane` already says overview — that is what the
                // grid is — so there is no change for the stack to follow.
                path = [.overview]
            } else {
                appState.selectedPane = pane
            }
        case .chat(let mode):
            appState.openChat(mode: mode)
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
            OverviewView(session: session)
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
            SettingsView(session: session)
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

// MARK: - tiles

/// One square of the home grid.
///
/// **The order is Android's**, row for row, so someone who knows where
/// Cmail is on their phone finds it in the same place here. Where Android
/// has a tile this app has no screen for yet (TOTP, Todo, Carve), the
/// slot goes to the nearest thing it does have; the tiles Android lacks
/// follow at the end.
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
        pane(.overview), pane(.secrets, String(localized: "Secret")), pane(.files),
        pane(.logs), pane(.transactions, String(localized: "TX")), pane(.cash),
        pane(.helpBeginners, String(localized: "First FCH")),
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
