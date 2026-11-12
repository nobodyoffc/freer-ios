import SwiftUI
import UIKit
import FCUI

/// Form controls shared by the two workbench panes, ``ToolsView`` and
/// ``ConvertView``. Both are the same shape of screen — paste something
/// in, press a button, read something out — so they share the input
/// editor, the error rendering, and the labelled result row.

/// Multiline monospaced editor with a subtle border — for ciphers,
/// signature JSON, scripts, and long messages.
struct ToolTextEditor: View {
    let placeholder: String
    @Binding var text: String
    var minHeight: CGFloat = 64

    var body: some View {
        // The chrome is FCUI's, so a workbench editor focuses and hovers
        // like every other input. The placeholder is an overlay rather
        // than the other half of a ZStack because the focus binding has
        // to land on the TextEditor itself, not on a container.
        TextEditor(text: $text)
            .font(.system(.body, design: .monospaced))
            .fieldEditorStyle(minHeight: minHeight)
            .overlay(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .foregroundStyle(.tertiary)
                        .font(.system(.body, design: .monospaced))
                        .padding(.top, 10)
                        .padding(.leading, 11)
                        .allowsHitTesting(false)
                }
            }
    }
}

/// One `label: value` line of a multi-part result — the address table,
/// the public-key forms, the encodings of a string.
///
/// The value wraps rather than scrolling: these are 130-character
/// public keys and 42-character addresses that users read across, and
/// **a click anywhere on the value copies the whole of it**.
///
/// Note the absence of `.textSelection(.enabled)`. It looks like a free
/// addition and is not: selectable text takes the mouse for
/// drag-to-select, so the tap never reaches `CopyableText` and the
/// click-to-copy this app relies on everywhere silently stops working.
/// One-click copy beats hand-selecting a 130-character key anyway.
///
/// The QR button is Android's per-result `makeQrIcon`, and it sits on
/// the label line rather than beside the value so it can never steal a
/// click meant for the copy.
struct ToolResultRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                // A tap on the value copies it too, but nothing on a
                // phone says so: no pointer, no hover.
                ToolValueActions(label: label, value: value)
            }
            CopyableText(value, font: .system(.body, design: .monospaced))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A block of ``ToolResultRow``s on the standard result background.
struct ToolResultTable: View {
    let rows: [(String, String)]

    var body: some View {
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(rows, id: \.0) { row in
                    ToolResultRow(label: row.0, value: row.1)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(NSColor.textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }
}

/// Copy and QR buttons for one value: beside every result, and beside
/// the Time converter's fields, which are all inputs and all outputs and
/// so cannot copy on a tap — a tap there places the caret.
struct ToolValueActions: View {
    let label: String
    let value: String

    @State private var showQr = false
    @State private var copied = false

    var body: some View {
        HStack(spacing: 2) {
            Button {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(value, forType: .string)
                copied = true
                Task {
                    try? await Task.sleep(nanoseconds: 1_200_000_000)
                    await MainActor.run { copied = false }
                }
            } label: {
                Image(systemName: copied ? "checkmark.circle.fill" : "doc.on.doc")
                    .frame(width: 32, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .foregroundStyle(copied ? Color.green : Color.secondary)
            .help(copied ? "Copied!" : "Copy “\(label)”")
            .animation(.easeInOut(duration: 0.15), value: copied)

            Button {
                showQr = true
            } label: {
                Image(systemName: "qrcode")
                    .frame(width: 32, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .help("Show “\(label)” as a QR code")
        }
        .disabled(value.isEmpty)
        .opacity(value.isEmpty ? 0 : 1)
        .sheet(isPresented: $showQr) {
            // QrDisplaySheet chunks anything past one code's capacity,
            // so a pretty-printed JSON blob paginates instead of failing.
            QrDisplaySheet(title: label, content: value) { showQr = false }
        }
    }
}

/// Our `Failure` enums are `CustomStringConvertible`, so
/// `String(describing:)` surfaces their message. Foreign `NSError`s
/// read acceptably too.
func errorText(_ error: Error) -> String {
    String(describing: error)
}

// MARK: - the form's buttons, in the pane's bottom bar

/// One button a workbench form wants in its pane's bottom bar.
///
/// The forms sit inside the pane's scroller, and the bar belongs to the
/// pane, outside it. So a form says what its buttons are — as a
/// preference, the way a view says its title — and the pane draws them.
struct ToolBarAction: Equatable {
    let title: String
    let systemImage: String
    var disabled = false
    /// Which form this came from; see ``ToolBarActionsModifier``.
    fileprivate var owner = UUID()
    let action: () -> Void

    init(_ title: String, systemImage: String, disabled: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.disabled = disabled
        self.action = action
    }

    /// The closure is left out: two closures cannot be compared, and
    /// one made on an earlier pass of the same form still reads and
    /// writes that form's `@State`.
    static func == (a: ToolBarAction, b: ToolBarAction) -> Bool {
        a.title == b.title && a.systemImage == b.systemImage
            && a.disabled == b.disabled && a.owner == b.owner
    }
}

private struct ToolBarActionsKey: PreferenceKey {
    static let defaultValue: [ToolBarAction] = []
    static func reduce(value: inout [ToolBarAction], nextValue: () -> [ToolBarAction]) {
        value += nextValue()
    }
}

/// Stamps the actions with the form they belong to. Seven converters
/// each have a Convert and a Clear that look alike; without the stamp,
/// switching from one to the next would be no change, and the bar would
/// go on pressing the buttons of the form that had left.
private struct ToolBarActionsModifier: ViewModifier {
    @State private var owner = UUID()
    let actions: [ToolBarAction]

    func body(content: Content) -> some View {
        content.preference(key: ToolBarActionsKey.self, value: actions.map {
            var action = $0
            action.owner = owner
            return action
        })
    }
}

/// Holds what the form on screen asked for, and draws it.
private struct ToolBottomBar: ViewModifier {
    @State private var actions: [ToolBarAction] = []

    func body(content: Content) -> some View {
        content
            .onPreferenceChange(ToolBarActionsKey.self) { actions = $0 }
            .bottomBar {
                ForEach(actions.indices, id: \.self) { index in
                    let item = actions[index]
                    Button(action: item.action) {
                        Label(item.title, systemImage: item.systemImage)
                    }
                    .disabled(item.disabled)
                }
            }
    }
}

extension View {
    /// A workbench form's buttons, in the order the bar shows them:
    /// Clear at the left, then the operation, next to Back.
    func toolBarActions(_ actions: [ToolBarAction]) -> some View {
        modifier(ToolBarActionsModifier(actions: actions))
    }

    /// The bottom bar of a pane whose forms use ``toolBarActions(_:)``.
    func toolBottomBar() -> some View {
        modifier(ToolBottomBar())
    }
}
