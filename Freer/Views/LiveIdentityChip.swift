import SwiftUI
import FCDomain
import FCUI

/// Who you are living as, at the right end of every pane's title bar —
/// Android's `toolbar_fid_container`.
///
/// The home screen draws the identity in full; a pane pushed over it
/// hides that card to have the width for itself, and this is what is
/// left of it: the CID, or the FID when there is none, and the avatar.
///
/// As on Android, the name copies the FID and the avatar goes home.
struct LiveIdentityChip: View {
    @Environment(AppState.self) private var appState
    let session: ActiveSession
    let goHome: () -> Void

    var body: some View {
        let info = appState.liveFidInfo
        let fid = session.liveFid
        HStack(spacing: 6) {
            Group {
                if let info, info.hasCid {
                    CopyableText(
                        display: info.displayName,
                        copy: fid,
                        font: .caption,
                        color: .secondary,
                        help: String(localized: "Copy this identity's FID.")
                    )
                    .truncationMode(.middle)
                } else {
                    CopyableText.elidingMiddle(
                        fid, head: 5, tail: 4,
                        font: .caption.monospaced(),
                        color: .secondary
                    )
                }
            }
            .lineLimit(1)
            .frame(maxWidth: 110, alignment: .trailing)

            Button(action: goHome) {
                FidAvatarView(fid: fid, size: 28, isNobody: info?.isNobody == true)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Home"))
        }
    }
}
