import SwiftUI
import UIKit

/// A tap anywhere that is not a text input puts the keyboard away.
///
/// A phone's keyboard covers the lower half of the screen — where the
/// results are, and the bottom bar — and iOS gives a multi-line editor no
/// key to dismiss it with. Android's Back does that job; here the tap
/// does. The tap is not taken from whatever it landed on: a button under
/// it is still pressed.
///
/// On the window, like ``ActivityWatch``, so sheets are covered too.
struct KeyboardDismissOnTap: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = Probe()
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {}

    private final class Probe: UIView, UIGestureRecognizerDelegate {
        private var recognizer: UITapGestureRecognizer?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            if let recognizer {
                recognizer.view?.removeGestureRecognizer(recognizer)
                self.recognizer = nil
            }
            guard let window else { return }
            let tap = UITapGestureRecognizer(target: self, action: #selector(tapped(_:)))
            tap.cancelsTouchesInView = false
            tap.delaysTouchesBegan = false
            tap.delaysTouchesEnded = false
            tap.delegate = self
            window.addGestureRecognizer(tap)
            recognizer = tap
        }

        @objc private func tapped(_ tap: UITapGestureRecognizer) {
            tap.view?.endEditing(true)
        }

        func gestureRecognizer(_ recognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            // In an input: the tap is placing the caret, or moving to
            // another field, and the keyboard stays for it.
            var view = touch.view
            while let current = view {
                if current is UITextField || current is UITextView { return false }
                view = current.superview
            }
            // Beside one that asked to keep it.
            if let window = recognizer.view {
                let point = touch.location(in: window)
                for keeper in KeyboardKeeper.Marker.all.allObjects
                where keeper.window === window && keeper.convert(keeper.bounds, to: window).contains(point) {
                    return false
                }
            }
            return true
        }

        func gestureRecognizer(
            _: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith _: UIGestureRecognizer
        ) -> Bool { true }
    }
}

/// Marks an area where a tap leaves the keyboard up — the row a message
/// is typed in, whose Send button is pressed again and again mid-typing.
struct KeyboardKeeper: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = Marker()
        view.isUserInteractionEnabled = false
        Marker.all.add(view)
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {}

    final class Marker: UIView {
        /// Weakly held: a marker leaves with its view.
        static let all = NSHashTable<Marker>.weakObjects()
    }
}

extension View {
    /// Taps on this view do not dismiss the keyboard.
    func keepsKeyboard() -> some View {
        background(KeyboardKeeper())
    }
}
