import SwiftUI

/// One of a handful of choices, each a chip with its whole name on it,
/// wrapping onto as many lines as they need.
///
/// The Mac's segmented control gives every segment the same share of the
/// row, which on a window is plenty and on a phone is forty points for
/// "WIF uncompressed": seven converters across one line read "Sc…",
/// "Pri…", "Pu…". Android hides the same choices in a popup menu; chips
/// keep them all in sight and one tap away, and say which one is on.
struct ChoiceChips<Value: Hashable>: View {
    /// What is being chosen, for VoiceOver. Not drawn.
    let label: LocalizedStringKey
    @Binding var selection: Value
    let options: [(value: Value, title: String)]

    init(_ label: LocalizedStringKey, selection: Binding<Value>, options: [(Value, String)]) {
        self.label = label
        self._selection = selection
        self.options = options.map { (value: $0.0, title: $0.1) }
    }

    var body: some View {
        FlowRow(spacing: 6) {
            ForEach(options.indices, id: \.self) { index in
                let option = options[index]
                let chosen = option.value == selection
                Button {
                    selection = option.value
                } label: {
                    Text(option.title)
                        .font(.subheadline)
                        .lineLimit(1)
                        .fixedSize()
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .foregroundStyle(chosen ? Color.white : Color.primary)
                        .background(
                            chosen ? Color.accentColor : Color(uiColor: .tertiarySystemFill),
                            in: Capsule()
                        )
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(chosen ? .isSelected : [])
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(label))
    }
}

extension ChoiceChips where Value: CaseIterable & RawRepresentable, Value.RawValue == String {
    /// Every case of an enum, named by its raw value — what the pickers
    /// this replaces did with `Text($0.rawValue)`.
    init(_ label: LocalizedStringKey, selection: Binding<Value>) {
        self.init(label, selection: selection, options: Value.allCases.map { ($0, $0.rawValue) })
    }
}
