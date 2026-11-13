# Freer for iOS

The iPhone/iPad client of Freer. Android (`~/AndroidStudioProjects/Freer`) and
Mac (`~/MacApp/FreerForMac`) are the two existing clients; this one is built
from the Mac's Swift code and laid out like the Android app.

## Where the code lives

- **Logic is not in this folder.** `FCCore`, `FCTransport`, `FCStorage`,
  `FCDomain`, `FCUI` and `FCVoice` are the Mac repo's packages, referenced by
  path (`../../MacApp/FreerForMac/Packages/*`). A fix to the wallet, a protocol or
  the transport is made there and reaches both apps. The Mac repo must sit
  beside this one's parent folder (`~/iosapp`) for the project to build.
- **`Freer/`** is the app: a copy of the Mac's `Sources/FreerForMac`
  (`Config/mac-source-revision.txt` records the commit it was taken from),
  adapted for iOS. It is a fork, not a reference: a change to a Mac view has to
  be brought over by hand.
- **`Freer/Platform/`** is what exists only here: the wrapping toolbar row,
  sheet sizing, the open-panel stand-in, touch tracking for auto-lock, the ringer.
- **`Freer/Views/HomeView.swift`** is the Android-style home grid. Tiles are
  listed in `HomeTile.all`, in Android's order. It is also the overview: the
  Mac's Overview pane is not here (`WalletPane.overview` means the grid).
  Tiles carry Android's red counts (`HomeBadges`): unread chats and Cmail,
  invitations awaiting an answer, and cashes the Cash pane has not shown
  (`Freer/SeenCashes.swift`). An unpaid DOCK is a line above the grid.
- The gear on the home screen is a menu, as on Android: one row per
  `SettingsPage` (`SettingsView` shows one page at a time), Back up prikey,
  then First FCH and Logs, which have no tile.
- Not ported, on purpose: the SSH terminal and Release Sync (both run
  subprocesses, which iOS does not allow) and the menu-bar item.

## How Mac views are made to work on iOS

- AppKit names the views use (`NSImage`, `NSColor.controlBackgroundColor`,
  `NSPasteboard`) are given UIKit meanings in
  `FCUI/Platform/AppKitCompat.swift`, compiled for iOS only. A file that uses
  them must `import FCUI`.
- `NSOpenPanel` → the stand-in in `Platform/OpenPanel.swift`; `runModal()` is
  `async` there, so the call sits in a `Task` with `await`.
- `NSSavePanel` → `FilePanel.export(named:write:)`: write first, then the user
  picks where the copy goes.
- A window-sized `.frame(width: 560)` → `.sheetFrame(...)` with the same
  arguments. A pane toolbar's `HStack` → `FlowRow`, which wraps.
- `.buttonStyle(.link)` → `.borderless`; `.toggleStyle(.checkbox)` → `.checkmark`.
- A segmented `Picker` with more or longer labels than a phone's width holds
  (the Convert and Tools panes) → `ChoiceChips`, which wraps.

## Phone layout: buttons at the bottom

Every pane and sheet in `Freer/Views` has one. Left as they were: the call
and meeting screens (`Freer/Calls`), `ChooseMainView`, the person menu, and
the sheets that live in the shared `FCUI` package (QR display and scan, the
avatar), which keep their own Done.

- A screen's actions go in `.bottomBar { … }` (`Platform/BottomBar.swift`), in
  Android's order: more, secondary, primary, then Back, which the bar adds
  itself. A sheet passes what its Cancel/Close did: `.bottomBar(back:) { … }`.
  Sort, filter and search stay at the top. The bar must be applied outside the
  pane's `.padding()`, or it stops short of the screen's edges.
- Buttons in the bar, and in rows marked `.roundButtons()`, are Android's:
  round and filled with the accent colour (grey when disabled). A `Label`
  there shows its icon only. Don't give a button there a style of its own. Actions that are unusual or cannot be undone keep their words
  (a `Text` with `.frame(minHeight: 30)` to match the icons' height).
- Convert and Tools hold several forms in one pane. Each form names its
  buttons with `.toolBarActions([...])`, Clear first and the operation last,
  and the pane draws them with `.toolBottomBar()` (`ToolFormControls.swift`).
- A sheet with a bottom bar uses `sheetFrame(width:height:)`, so its own
  scroller is the only one and the bar stays put.
- The live identity at the right of every pane's title bar is
  `LiveIdentityChip`, added once in `HomeView`'s `navigationDestination`,
  where the pane's title is also put at the left end.
- A view brought over from the Mac arrives with its buttons in a toolbar
  `FlowRow` or a footer `HStack` again: move them into the bar, and in a merge
  keep the iOS side of conflicts around toolbars and footers.

## Languages

English is the source language and Simplified Chinese follows the system
setting. User-facing strings that are not SwiftUI literals go through
`String(localized:)`; numbers and errors are interpolated as `String(...)` so
every placeholder in a key is `%@`. System log lines and anything stored or
sent on the wire stay English.

Settings has a language picker (`Freer/AppLanguage.swift`): Follow system,
English or 简体中文, stored as `AppleLanguages` in the app's own defaults — the
same value the Settings app's per-app language writes — and applied at the
next launch. iOS has no Restart button, as the Mac has: an app cannot relaunch
itself.

`Freer/Localization/zh-Hans.lproj/Localizable.strings` has two parts: the
iOS-only entries at the top, edited by hand, and the Mac app's table below
the marker line, regenerated by `tools/sync-localization.sh` ("this Mac"
becomes "this device" in keys and values). The home tiles use Android's
Chinese names.

## Bringing Mac view changes over

`Config/mac-source-revision.txt` is the Mac commit `Freer/` was last merged
from. To take newer changes, three-way merge each file with `git merge-file`
(ours = the iOS file, base = the Mac file at the recorded commit, theirs = the
Mac file at the new commit), keep the iOS side of conflicts around file panels
and alerts, and update the recorded commit. Rewording "this device" back to
"this Mac" on the iOS side first removes most of the false conflicts.

Taken out of order since that commit: the language setting (`be3995d`).
Deliberately not taken: larger controls (`d9338b7`).

## Build and check

    tools/build.sh                 # simulator build; prints errors and the verdict
    tools/walkthrough.sh <simulator-udid> <shots-dir>

The walkthrough is a UI test that makes a vault and an identity, opens every
home tile and settings-menu row and saves a screenshot of each — the way to see a layout change on
a phone. Run it after touching a pane. `testWorkbenchBars` presses the Convert and Tools bars. `testChineseScreens` does a shorter
pass in Chinese, and `testBottomBarScreens` opens a few panes and a sheet
from each, backing out with the bars' own Back (pass either as
the fourth argument, after a derived-data dir, as
`FreerUITests/WalkthroughTests/<name>`). `xcrun simctl list devices` gives a UDID.

No signing team is set: simulator builds work as is, a device build needs
`DEVELOPMENT_TEAM` in the target's settings. Bundle id `cash.freer.ios`.
