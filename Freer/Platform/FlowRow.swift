import SwiftUI

/// A row that wraps: its children sit side by side like an `HStack`'s
/// until they run out of width, and then carry on underneath.
///
/// The panes' toolbars were laid out for a Mac window — a filter, a
/// search field and three buttons in one line is ordinary there, and
/// half as wide again as a phone. An `HStack` cannot be narrower than
/// its children, so the whole pane came out wider than the screen and
/// was cut off at both edges. This keeps every control, at its own size,
/// and lets the row grow downwards instead.
struct FlowRow: Layout {
    var alignment: VerticalAlignment
    var spacing: CGFloat
    /// Between one line and the next.
    var lineSpacing: CGFloat = 8

    init(alignment: VerticalAlignment = .center, spacing: CGFloat? = nil) {
        self.alignment = alignment
        self.spacing = spacing ?? 8
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let lines = arrange(subviews, within: proposal.width ?? .infinity)
        let width = lines.map(\.width).max() ?? 0
        let height = lines.map(\.height).reduce(0, +) + lineSpacing * CGFloat(max(lines.count - 1, 0))
        // Offered a width, take it: a toolbar is as wide as its pane, so
        // what follows it lines up with what came before.
        return CGSize(width: proposal.width.map { $0.isFinite ? $0 : width } ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for line in arrange(subviews, within: bounds.width) {
            var x = bounds.minX
            for item in line.items {
                let dy: CGFloat
                switch alignment {
                case .top: dy = 0
                case .bottom: dy = line.height - item.size.height
                default: dy = (line.height - item.size.height) / 2
                }
                subviews[item.index].place(
                    at: CGPoint(x: x, y: y + dy),
                    proposal: ProposedViewSize(item.size)
                )
                x += item.size.width + spacing
            }
            y += line.height + lineSpacing
        }
    }

    private struct Item {
        let index: Int
        let size: CGSize
    }

    private struct Line {
        var items: [Item] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(_ subviews: Subviews, within maxWidth: CGFloat) -> [Line] {
        var lines: [Line] = []
        var current = Line()
        for index in subviews.indices {
            let subview = subviews[index]
            // A `Spacer` pushes an `HStack`'s ends apart. Wrapped lines
            // have no ends to push, so here it is nothing at all.
            let most = subview.sizeThatFits(ProposedViewSize(width: .infinity, height: .infinity))
            if most.width == .infinity && most.height == .infinity { continue }

            var size = subview.sizeThatFits(.unspecified)
            if size.width > maxWidth {
                // Wider than the whole row by itself: it gets a line of
                // its own, squeezed to fit.
                size = subview.sizeThatFits(ProposedViewSize(width: maxWidth, height: nil))
            }
            let needed = current.items.isEmpty ? size.width : current.width + spacing + size.width
            if needed > maxWidth, !current.items.isEmpty {
                lines.append(current)
                current = Line()
            }
            current.width = current.items.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.items.append(Item(index: index, size: size))
        }
        if !current.items.isEmpty { lines.append(current) }
        return lines
    }
}
