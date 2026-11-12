import SwiftUI
import UIKit

@main
struct FreerApp: App {

    @State private var appState = AppState()

    init() {
        // Read before anything changes it: Settings compares the saved
        // choice against this to know a restart is still owed.
        _ = AppLanguage.atLaunch
    }

    var body: some Scene {
        WindowGroup {
            AppRouter()
                .environment(appState)
                .background(ActivityWatch { [appState] in appState.noteUserActivity() })
                .background(KeyboardDismissOnTap())
                .background(ThemeApplier(appState: appState))
        }
    }
}

/// Gives the window the theme ``AppState`` last chose.
///
/// ``AppState/applyTheme(_:)`` sets it on every window that exists at the
/// time. This covers the one that does not yet: the first, which comes up
/// after the state is built.
private struct ThemeApplier: UIViewRepresentable {
    let appState: AppState

    func makeUIView(context: Context) -> UIView { Probe(appState: appState) }
    func updateUIView(_ view: UIView, context: Context) {}

    private final class Probe: UIView {
        private let appState: AppState

        init(appState: AppState) {
            self.appState = appState
            super.init(frame: .zero)
            isUserInteractionEnabled = false
        }

        required init?(coder: NSCoder) { fatalError("not used") }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            window?.overrideUserInterfaceStyle = appState.themeStyle
        }
    }
}
