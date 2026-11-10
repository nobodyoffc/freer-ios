import UIKit
import SwiftUI
import FCCore
import FCDomain
import FCUI

/// What going ahead with a nobody would cost. The sentences match
/// Android's `nobody_consequence_*` strings, so both apps say the same
/// thing about the same risk. See `NOBODY_SPEC.md`.
enum NobodyConsequence {
    case send, sendFrom, encrypt, mail, multisig, master
    case team, room, teamOwner, rate, contact, chat, importKey

    var text: String {
        switch self {
        case .send:
            return "Anything sent to it can be taken by anyone."
        case .sendFrom:
            return "The sender's prikey is public. Anyone can spend the same cash first, so this transaction may never confirm."
        case .encrypt:
            return "Anyone can decrypt what you encrypt to it."
        case .mail:
            return "Anyone can read this Cmail and reply as the recipient."
        case .multisig:
            return "Anyone can sign as this member, so the multisig needs fewer real signatures than it appears."
        case .master:
            return "Setting a master publishes your prikey encrypted to the master. Anyone can decrypt it and take this identity for good."
        case .team:
            return "Anyone can read the team's messages and act as these members, including giving their consent."
        case .room:
            return "Anyone can read the room's messages and speak as these members."
        case .teamOwner:
            return "Anyone could run the team as its owner."
        case .rate:
            return "Anyone can act as it, so its reputation means nothing. The coin days you destroy to rate it are wasted."
        case .contact:
            return "Anyone can speak as it, change its CID, and read what you send it."
        case .chat:
            return "Anyone can read this conversation and write as it."
        case .importKey:
            return "Anyone can spend this key's funds, read its messages and act as it. Use it only as a public identity."
        }
    }
}

/// Lines shown under a nobody's name wherever the consequence needs saying.
enum NobodyText {
    static let identity = "Nobody: this identity's prikey is public. Anyone can act as it."
    static let selfIdentity = "This identity's prikey is public. Anyone can spend its funds, read its messages and act as it."
    static let receive = "This address's prikey is public. Anything paid here can be taken by anyone."
    static let sender = "The sender is a nobody: its prikey is public, so anyone could have sent this."
    static let inviter = "The inviter is a nobody: its prikey is public, so anyone could have sent this invitation."
    static let partner = "This identity is a nobody: its prikey is public, so messages from it can be written by anyone and cannot be trusted."
    static let signature = "Valid, but the signer is a nobody: its prikey is public, so anyone could have signed this. It proves nothing."
    static let consensus = "Nobody members' prikeys are public: anyone can give their consent."
    static let contentHidden = "[Content from an unverifiable (nobody) identity is not shown]"
}

/// The confirmation before any action that involves a nobody.
///
/// **Never a block.** The user may mean it — funding the public board,
/// encrypting something they intend to publish. But the consequence is
/// said plainly and nothing proceeds until they choose to.
///
/// **An app-modal alert, not a sheet.** Most of these actions start from
/// inside a sheet, and SwiftUI will not reliably stack another — the same
/// reason ``TxApprovalHost`` uses a window. A `UIAlertController` presented
/// from the frontmost controller sits above whatever is open.
@MainActor
enum NobodyGate {

    /// True when none of `fids` is a nobody, or the user chose to go ahead.
    /// Unknown FIDs are checked against the nobody index first; if that
    /// fails, the decision rests on what is already known.
    static func confirm(
        _ fids: [String?],
        _ consequence: NobodyConsequence,
        session: ActiveSession?
    ) async -> Bool {
        let candidates = fids.compactMap { $0 }.filter { !$0.isEmpty }
        guard !candidates.isEmpty else { return true }
        let registry = NobodyRegistry.shared
        if let session, !registry.unknown(among: candidates).isEmpty {
            let directory = session.directory
            await registry.resolve(candidates, retryFailed: true) { fids in
                await directory.nobodyFids(among: fids)
            }
        }
        let nobodies = registry.nobodies(among: candidates)
        guard !nobodies.isEmpty else { return true }
        return await ask(nobodies, consequence)
    }

    /// ``confirm(_:_:session:)`` for hex pubkeys; anything that isn't one is ignored.
    static func confirm(
        pubkeys: [String],
        _ consequence: NobodyConsequence,
        session: ActiveSession?
    ) async -> Bool {
        await confirm(pubkeys.map { NobodyRegistry.fid(ofPubkeyHex: $0) }, consequence, session: session)
    }

    private static func ask(_ nobodies: [String], _ consequence: NobodyConsequence) async -> Bool {
        let list = nobodies.map { "• \($0)" }.joined(separator: "\n")
        return await withCheckedContinuation { continuation in
            let alert = UIAlertController(
                title: "Nobody identity",
                message: "Prikey published on chain:\n\(list)\n\n\(consequence.text)",
                preferredStyle: .alert
            )
            // Cancel is the preferred action: the bold button, and the
            // one Return presses on a keyboard, must never be the risky answer.
            let cancel = UIAlertAction(title: "Cancel", style: .cancel) { _ in
                continuation.resume(returning: false)
            }
            alert.addAction(cancel)
            alert.addAction(UIAlertAction(title: "Proceed Anyway", style: .destructive) { _ in
                continuation.resume(returning: true)
            })
            alert.preferredAction = cancel
            guard let host = FilePanel.topViewController() else {
                // Nowhere to ask: not asking is not consent.
                continuation.resume(returning: false)
                return
            }
            host.present(alert, animated: true)
        }
    }

    /// Tell the user, once per FID, that one of their own keys is a nobody.
    static func alertOwnKeyIfNeeded(_ fid: String) {
        guard NobodyRegistry.shared.claimOwnKeyAlert(fid) else { return }
        let alert = UIAlertController(
            title: "Your prikey is public",
            message: "The prikey of \(fid) has been published on chain. Anyone can spend its funds, read its messages and act as it. Move your funds to a key only you hold.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        FilePanel.topViewController()?.present(alert, animated: true)
    }
}
