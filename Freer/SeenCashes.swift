import Foundation
import FCDomain

/// Which of an identity's cashes it has already been shown, so the home
/// grid can count the ones it has not — Android's `Cash.isNew`, which
/// lights the badge on its Cash tile.
///
/// Android keeps the flag on each cash row. The cash cache here is the
/// shared package's and the Mac has no such badge, so the flag is kept
/// beside the cache instead: the outpoints that were in it the last time
/// the Cash pane was open. A cash not on that list is new, whoever made
/// it — a payment received, or the change of one sent.
///
/// In the vault's encrypted store, keyed by FID: a list of outpoints in
/// the clear would say which coins this phone watches.
enum SeenCashes {
    private static let namespace = "ios.seencashes.v1"

    private static func outpoints(of session: ActiveSession) -> [String] {
        let cashes = (try? session.cashes.snapshot(forAddress: session.liveFid))?.cashes ?? []
        return cashes
            // A cash on its way out is not news, and nor is one already spent.
            .filter { $0.valid != false && !$0.pendingSpend }
            .map { "\($0.birthTxId):\($0.birthIndex)" }
    }

    /// How many cashes the live FID holds that its Cash pane has not shown.
    static func newCount(for session: ActiveSession) -> Int {
        let seen = Set((try? session.storage.get([String].self, namespace: namespace, key: session.liveFid)) ?? [])
        return outpoints(of: session).filter { !seen.contains($0) }.count
    }

    /// The Cash pane is, or has just been, on screen: everything now in
    /// the cache has been seen. Replaces the list rather than adding to
    /// it, so it never outgrows the cache it describes.
    static func markAllSeen(for session: ActiveSession) {
        try? session.storage.put(outpoints(of: session), namespace: namespace, key: session.liveFid)
    }
}
