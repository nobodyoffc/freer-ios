import SwiftUI

// How big a sheet is, on a platform where that is not the sheet's to say.
//
// On the Mac every sheet and panel sizes itself: `.frame(width: 560)` on
// the root *is* the window's width. An iPhone sheet is the size the
// system makes it, and a 560-point frame inside a 393-point screen is
// simply cut off at both edges. So wherever the Mac views fix a
// window-sized frame, the iOS copies say `sheetFrame` with the same
// arguments, and it means "fill what you are given" instead.
//
// The numbers are kept at the call sites rather than deleted: on an iPad,
// where a sheet has room, they are still the right size to ask for.
extension View {

    /// A sheet the Mac sizes by width alone, letting the content decide
    /// the height. On a phone that content can be taller than the
    /// screen, so it scrolls.
    func sheetFrame(width: CGFloat) -> some View {
        modifier(SheetFrame(idealWidth: width, fillsHeight: false))
    }

    /// A sheet the Mac gives a fixed box. Its content already manages
    /// its own height — a list, an editor — so here it fills the sheet.
    func sheetFrame(width: CGFloat, height: CGFloat) -> some View {
        modifier(SheetFrame(idealWidth: width, fillsHeight: true))
    }

    func sheetFrame(
        minWidth: CGFloat? = nil,
        idealWidth: CGFloat? = nil,
        maxWidth: CGFloat? = nil,
        minHeight: CGFloat? = nil,
        idealHeight: CGFloat? = nil,
        maxHeight: CGFloat? = nil,
        alignment: Alignment = .center
    ) -> some View {
        modifier(SheetFrame(
            idealWidth: idealWidth ?? minWidth ?? 0,
            // A minimum width is how the Mac says "this is a pane, and
            // the window may not squeeze it": it takes whatever room there
            // is and scrolls inside itself. Only a fixed `width:` marks a
            // sheet sized by its content.
            fillsHeight: true
        ))
    }
}

private struct SheetFrame: ViewModifier {
    let idealWidth: CGFloat
    let fillsHeight: Bool

    func body(content: Content) -> some View {
        if fillsHeight {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        } else {
            ScrollView {
                content
                    .frame(maxWidth: .infinity, alignment: .top)
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollBounceBehavior(.basedOnSize)
        }
    }
}

/// A tick box: what `.toggleStyle(.checkbox)` is on the Mac. The iOS
/// switch is the wrong control for "select these rows" — it reads as a
/// setting being turned on, and a column of them fills the row.
struct CheckmarkToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                    .foregroundStyle(configuration.isOn ? Color.accentColor : Color.secondary)
                    .imageScale(.large)
                configuration.label
                    .foregroundStyle(.primary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

extension ToggleStyle where Self == CheckmarkToggleStyle {
    static var checkmark: CheckmarkToggleStyle { CheckmarkToggleStyle() }
}
