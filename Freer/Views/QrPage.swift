import SwiftUI
import FCUI

/// FCUI's QR page in this app's frame: the title on top, its buttons in
/// the bottom bar — Clear, Make QR, Copy or Done, Scan — then Back.
/// The toolbar's QR button opens it (`QrToolSheet`) to scan, read pictures and make
/// codes. (The same file is in Safe for iOS.)
struct QrPage: View {
    var title: String = String(localized: "QR Code")
    var onDone: ((String) -> Void)? = nil
    var onCancel: (() -> Void)? = nil

    var body: some View {
        QrCodeView(onDone: onDone) { page, buttons in
            page
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .bottomBar(back: onCancel) { buttons }
        }
    }
}

/// The QR page as a sheet, for a screen that wants a scanned text back:
/// Done hands it over, Back leaves without it.
struct QrScanSheet: View {
    var title: String = String(localized: "Scan QR code")
    let onUse: (String) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            QrPage(title: title, onDone: onUse, onCancel: onCancel)
        }
    }
}
