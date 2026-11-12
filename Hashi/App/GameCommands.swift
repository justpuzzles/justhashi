import SwiftUI

/// What the board screen offers the menu bar. Published by `GameView` with
/// `focusedSceneValue`, so the menu items act on the game in the front window
/// and grey out when no board is showing.
struct BoardActions: Equatable {
    var canUndo: Bool
    var undo: () -> Void
    var canHint: Bool
    var hint: () -> Void

    /// By the flags alone. The closures are new on every redraw, and a
    /// focused value that never compares equal is republished on every
    /// redraw; the board screen then never went idle (UI tests timed out
    /// waiting for it).
    static func == (a: BoardActions, b: BoardActions) -> Bool {
        a.canUndo == b.canUndo && a.canHint == b.canHint
    }
}

extension FocusedValues {
    @Entry var boardActions: BoardActions?
}

#if os(macOS)
/// The Mac's menu-bar commands. Undo replaces the Edit menu's (there is no
/// text to undo anywhere in the app); Hint gets a Game menu. ⇧⌘H, because ⌘H
/// is the system's Hide.
struct GameCommands: Commands {
    @FocusedValue(\.boardActions) private var actions

    var body: some Commands {
        CommandGroup(replacing: .undoRedo) {
            Button("Undo Bridge") { actions?.undo() }
                .keyboardShortcut("z")
                .disabled(!(actions?.canUndo ?? false))
        }
        CommandMenu("Game") {
            Button("Hint") { actions?.hint() }
                .keyboardShortcut("h", modifiers: [.command, .shift])
                .disabled(!(actions?.canHint ?? false))
        }
    }
}
#endif
