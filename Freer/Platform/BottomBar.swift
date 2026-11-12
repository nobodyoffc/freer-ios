import SwiftUI
import UIKit

// Where a screen's buttons go on a phone: along the bottom, under the
// right thumb, in the order Freer for Android has them —
//
//     [more] [secondary …] [primary] [back]
//
// The Mac views put a pane's actions in a toolbar across the top and a
// sheet's in a footer that scrolls with its content. Both are a stretch
// on a phone held in one hand, and the system's Back button, top left, is
// the furthest point on the screen from that thumb.
//
// Back is always the last button, so the thumb learns one place for
// "leave this screen" whether the screen was pushed or presented.
extension View {

    /// A pane's bottom bar: `actions`, then Back. Takes the system Back
    /// button off the title bar; the swipe from the left edge stays.
    func bottomBar<Actions: View>(@ViewBuilder _ actions: @escaping () -> Actions) -> some View {
        modifier(BottomBar(back: nil, actions: actions))
    }

    /// A screen with nothing to do but leave.
    func bottomBar(back: (() -> Void)? = nil) -> some View {
        modifier(BottomBar(back: back, actions: { EmptyView() }))
    }

    /// A sheet's bottom bar. `back` is what its Cancel, Close or Later
    /// button did; nil leaves it to the system's dismiss.
    func bottomBar<Actions: View>(
        back: (() -> Void)?,
        @ViewBuilder _ actions: @escaping () -> Actions
    ) -> some View {
        modifier(BottomBar(back: back, actions: actions))
    }
}

private struct BottomBar<Actions: View>: ViewModifier {
    @Environment(\.dismiss) private var dismiss
    @State private var bottomInset: CGFloat = 0
    let back: (() -> Void)?
    let actions: () -> Actions

    /// The space under the buttons. On a phone with a home indicator the
    /// system keeps 34 points clear below the bar, most of it empty: the
    /// buttons move down into it, stopping short of the indicator itself.
    /// With no indicator, or with the keyboard up (an inset far larger
    /// than any indicator's), they keep a margin of their own.
    private var bottomPadding: CGFloat {
        bottomInset > 0 && bottomInset <= 50 ? -min(14, bottomInset - 20) : 6
    }

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 0) {
                    Divider()
                    HStack(spacing: 8) {
                        Spacer(minLength: 0)
                        actions()
                        Button {
                            if let back { back() } else { dismiss() }
                        } label: {
                            Label("Back", systemImage: "chevron.backward")
                        }
                    }
                    .roundButtons()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .padding(.bottom, bottomPadding)
                }
                .background(.bar)
            }
            // Measured outside the bar, so it is the screen's own inset
            // and not one the bar added.
            .onGeometryChange(for: CGFloat.self) { $0.safeAreaInsets.bottom } action: { bottomInset = $0 }
            .navigationBarBackButtonHidden(true)
            .background(EdgeSwipeBack())
    }
}

// MARK: - round, filled buttons

extension View {
    /// Android's buttons: round, filled with the accent colour, the icon
    /// or the words in white. A `Label` inside shows its icon alone and
    /// comes out as a circle; a `Text` comes out as a capsule.
    ///
    /// On a phone a bare tinted glyph or word does not read as something
    /// to press, least of all in a row of them.
    func roundButtons() -> some View {
        self
            .labelStyle(.barIcon)
            .buttonStyle(RoundFilledButtonStyle())
    }
}

/// The fill is the accent colour, or grey when the button is disabled —
/// still plainly a button, plainly not to be pressed. The system's own
/// filled style fades a disabled button to almost nothing, and a bar
/// with holes in it reads as a bar with fewer buttons.
struct RoundFilledButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.medium))
            .foregroundStyle(.white)
            .tint(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .frame(minWidth: 40, minHeight: 40)
            // `.tint`, not the accent colour outright: a button that asks
            // for green or red (Rate good, Rate bad) still gets it.
            .background(isEnabled ? AnyShapeStyle(.tint) : AnyShapeStyle(Color(uiColor: .systemGray3)), in: Capsule())
            .opacity(configuration.isPressed ? 0.6 : 1)
            .contentShape(Capsule())
    }
}

// MARK: - icons without their words

/// A label drawn as its icon alone, in a box a thumb can hit. The title
/// is still the button's name to VoiceOver.
///
/// For the actions whose symbol needs no caption — copy, refresh, show,
/// QR code. Anything unusual or irreversible keeps its words: give it a
/// plain `Text`, or `.labelStyle(.titleAndIcon)`.
struct BarIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        Label {
            configuration.title
        } icon: {
            configuration.icon
                .imageScale(.large)
                // A fixed box, so a wide glyph (the eye) and a narrow one
                // (the chevron) both make the same circle.
                .frame(width: 22, height: 30)
        }
        .labelStyle(.iconOnly)
    }
}

extension LabelStyle where Self == BarIconLabelStyle {
    static var barIcon: BarIconLabelStyle { BarIconLabelStyle() }
}

// MARK: - the edge swipe

/// Keeps the swipe-from-the-left-edge alive on a pushed screen whose
/// Back button is hidden. UIKit ties the gesture to that button; taking
/// over as the recogniser's delegate unties it.
private struct EdgeSwipeBack: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Probe { Probe() }
    func updateUIViewController(_ controller: Probe, context: Context) {}

    final class Probe: UIViewController, UIGestureRecognizerDelegate {
        private weak var navigation: UINavigationController?
        private weak var formerDelegate: UIGestureRecognizerDelegate?

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            guard let nav = navigationController,
                  let pop = nav.interactivePopGestureRecognizer,
                  pop.delegate !== self else { return }
            navigation = nav
            formerDelegate = pop.delegate
            pop.delegate = self
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            // Hand the gesture back, so a screen that kept its Back
            // button behaves exactly as the system has it.
            if let pop = navigation?.interactivePopGestureRecognizer, pop.delegate === self {
                pop.delegate = formerDelegate
            }
        }

        func gestureRecognizerShouldBegin(_ recogniser: UIGestureRecognizer) -> Bool {
            // At the root there is nothing to pop, and a pop begun
            // there leaves the navigation stack frozen.
            (navigation?.viewControllers.count ?? 0) > 1
        }
    }
}
