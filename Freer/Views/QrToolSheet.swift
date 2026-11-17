import SwiftUI
import FCUI

/// The QR page as a modal, opened from the toolbar `qrcode` button —
/// Android's `QrCodeActivity`: scan with the camera or from pictures
/// (each code appends, so payloads split across several codes merge back
/// together), edit the content, and render it as QR codes.
struct QrToolSheet: View {
    let onDone: () -> Void

    var body: some View {
        NavigationStack {
            QrPage(title: String(localized: "QR workbench"), onCancel: onDone)
        }
    }
}
