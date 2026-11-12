import SwiftUI

extension ToolbarContent {
    /// A title-bar item drawn as it is, with no capsule behind it.
    ///
    /// From iOS 26 the navigation bar puts every item on a glass capsule
    /// of its own, which suits a button and not a title or a name: the
    /// pane's title and the live identity came out as two bubbles, with
    /// the title squeezed to a letter. Earlier systems draw no capsule,
    /// so there is nothing to take away.
    @ToolbarContentBuilder
    func plainToolbarItem() -> some ToolbarContent {
        if #available(iOS 26.0, *) {
            sharedBackgroundVisibility(.hidden)
        } else {
            self
        }
    }
}
