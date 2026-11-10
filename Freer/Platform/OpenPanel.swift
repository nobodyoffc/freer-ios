import UIKit
import UniformTypeIdentifiers
import FCUI

/// The Mac's `NSOpenPanel`, as far as the views use it, over the iOS
/// document picker.
///
/// The views were written for the Mac, where choosing a file is three
/// lines: configure a panel, run it, read `url`. Keeping that shape here
/// means a view ported from the Mac changes by one word — `await` — and
/// stays recognisably the same code.
///
/// **What differs is where the file is.** A Mac panel returns the file
/// itself. This returns a *copy* inside the app's container (see
/// ``FilePanel/open(types:allowsMultiple:)``): readable for as long as
/// the caller needs with no security scope to manage, but not the
/// original, and not somewhere to keep a long-term reference to.
@MainActor
final class NSOpenPanel {
    enum ModalResponse { case OK, cancel }

    var allowsMultipleSelection = false
    var canChooseDirectories = false
    var canChooseFiles = true
    var canCreateDirectories = false
    var allowedContentTypes: [UTType] = []
    /// Shown by the Mac panel; the iOS picker has nowhere to put them.
    var message = ""
    var prompt = ""
    var title = ""

    private(set) var urls: [URL] = []
    var url: URL? { urls.first }

    func runModal() async -> ModalResponse {
        if canChooseDirectories && !canChooseFiles {
            urls = await FilePanel.chooseFolder().map { [$0] } ?? []
        } else {
            urls = await FilePanel.open(
                types: allowedContentTypes.isEmpty ? [.item] : allowedContentTypes,
                allowsMultiple: allowsMultipleSelection
            )
        }
        return urls.isEmpty ? .cancel : .OK
    }
}
