import SwiftUI
import UIKit
import FCUI
import FCDomain

/// Puts ``TxConfirmSheet`` on screen for whatever ``TxApprovalCenter``
/// is currently asking about.
///
/// **Why a window and not a `.sheet`.** Most transactions are started
/// from inside a sheet — the contact editor, the mail composer, the
/// Cash pane's Send — and SwiftUI will not reliably present a second
/// sheet from an *ancestor* while a descendant's sheet is up. It fails
/// by doing nothing, which here would mean a signing request that
/// waits forever on a dialog nobody can see: the worst possible
/// outcome for the one feature whose job is to never sign silently. A
/// floating panel is above the app's sheets by construction, and works
/// the same whether the request came from a pane, from a sheet inside
/// a pane, or from a background carve with no UI at all.
///
/// The panel has no close button on purpose. The buttons inside are
/// the only exits, so the question cannot be dismissed into
/// ambiguity — and ``TxApprovalCenter/cancelAll()`` handles the case
/// where the session disappears underneath it.
struct TxApprovalHost: View {
    let center: TxApprovalCenter
    /// Only used to put contact names on the addresses in the dialog.
    let session: ActiveSession?

    @State private var presenter = TxApprovalWindow()

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onChange(of: center.current?.id, initial: true) { _, id in
                if id == nil {
                    presenter.close()
                } else {
                    presenter.show(center: center, session: session)
                }
            }
    }
}

/// Owns the panel. Kept as a plain class in `@State` so the window
/// survives view updates — recreating it on every redraw would make
/// the dialog flicker.
///
/// **A `UIWindow` of its own, above the app's.** Presenting a view
/// controller would be the usual iOS way, and it has the failure this
/// type exists to rule out: UIKit drops a presentation that arrives
/// while another is animating, silently. A second window is simply on
/// top — of the panes, of their sheets, of a sheet half way through
/// appearing.
@MainActor
@Observable
final class TxApprovalWindow {
    @ObservationIgnored private var window: UIWindow?
    @ObservationIgnored private weak var previousKey: UIWindow?

    func show(center: TxApprovalCenter, session: ActiveSession?) {
        guard window == nil else { return }
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first else {
            return
        }
        let main = scene.windows.first { $0.isKeyWindow } ?? scene.windows.first
        let hosting = UIHostingController(
            rootView: TxApprovalWindowContent(center: center, session: session)
        )
        let panel = UIWindow(windowScene: scene)
        panel.rootViewController = hosting
        // Above everything the app shows, below the system's own alerts.
        panel.windowLevel = UIWindow.Level(rawValue: UIWindow.Level.alert.rawValue - 1)
        panel.overrideUserInterfaceStyle = main?.overrideUserInterfaceStyle ?? .unspecified
        previousKey = main
        window = panel
        panel.makeKeyAndVisible()
    }

    func close() {
        window?.isHidden = true
        window = nil
        previousKey?.makeKey()
        previousKey = nil
    }
}

/// The panel's content. Reads the centre directly so a queued request
/// slides into the same window when the current one is answered,
/// instead of closing and reopening.
private struct TxApprovalWindowContent: View {
    let center: TxApprovalCenter
    let session: ActiveSession?

    var body: some View {
        if let request = center.current {
            TxConfirmSheet(
                preview: request.preview,
                waiting: center.waitingCount,
                session: session
            ) { decision in
                center.answer(decision)
            }
            .id(request.id)
        } else {
            Color.clear
        }
    }
}
