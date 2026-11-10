import SwiftUI
import UIKit

/// Tells the app the user is here — every touch that lands on the window.
///
/// The auto-lock clock wants to know when the user last did something.
/// The Mac app asks AppKit for a local event monitor; UIKit has none, so
/// this hangs a gesture recognizer on the window that looks at every
/// touch and claims none of them.
///
/// **On the window, not on a view.** Sheets and pushed screens are other
/// views in the same window, so one recognizer there sees a tap anywhere
/// in the app. Mounted as the background of the root view only to find
/// that window.
struct ActivityWatch: UIViewRepresentable {
    let onActivity: () -> Void

    func makeUIView(context: Context) -> UIView {
        let view = Probe()
        view.isUserInteractionEnabled = false
        view.onActivity = onActivity
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        (view as? Probe)?.onActivity = onActivity
    }

    private final class Probe: UIView {
        var onActivity: (() -> Void)?
        private var recognizer: TouchWitness?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            if let recognizer {
                recognizer.view?.removeGestureRecognizer(recognizer)
                self.recognizer = nil
            }
            guard let window else { return }
            let witness = TouchWitness { [weak self] in self?.onActivity?() }
            window.addGestureRecognizer(witness)
            recognizer = witness
        }
    }
}

/// Sees touches begin and then fails, so every other recognizer and
/// control in the window behaves exactly as if it were not there.
private final class TouchWitness: UIGestureRecognizer {
    private let onTouch: () -> Void

    init(onTouch: @escaping () -> Void) {
        self.onTouch = onTouch
        super.init(target: nil, action: nil)
        cancelsTouchesInView = false
        delaysTouchesBegan = false
        delaysTouchesEnded = false
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        onTouch()
        state = .failed
    }

    override func canPrevent(_: UIGestureRecognizer) -> Bool { false }
    override func canBePrevented(by _: UIGestureRecognizer) -> Bool { false }
}
