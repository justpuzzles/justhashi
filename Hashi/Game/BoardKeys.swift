import SwiftUI
#if os(macOS)
import AppKit
#endif

/// What a key means on the board (Mac). Built from key codes and characters,
/// so the mapping is testable without synthesising events.
nonisolated enum BoardKey: Equatable, Sendable {
    case arrow(Direction)
    /// Space or Return: pick up the island under the cursor, or put it down.
    case pick
    /// Escape: put the picked-up island down.
    case drop

    static func from(keyCode: UInt16, characters: String, hasModifier: Bool) -> BoardKey? {
        guard !hasModifier else { return nil }   // menu shortcuts pass through
        switch keyCode {
        case 126: return .arrow(.up)
        case 125: return .arrow(.down)
        case 123: return .arrow(.left)
        case 124: return .arrow(.right)
        case 49, 36, 76: return .pick            // space, return, keypad enter
        case 53: return .drop                    // escape
        default: return nil
        }
    }
}

extension HashiPuzzle {
    /// The island the cursor should move to from `island` toward `direction`:
    /// the one a corridor leads to when there is one (where a bridge could go),
    /// otherwise the nearest island in that half of the board, so the cursor
    /// can reach islands no corridor connects. Nil when there is none.
    nonisolated func neighbour(of island: Int, toward direction: Direction) -> Int? {
        if let edge = edge(from: island, direction: direction) {
            return edges[edge].other(island)
        }
        let origin = islands[island].position
        let candidates = islands.filter { other in
            let dr = other.position.row - origin.row, dc = other.position.col - origin.col
            switch direction {
            case .up: return dr < 0
            case .down: return dr > 0
            case .left: return dc < 0
            case .right: return dc > 0
            }
        }
        // Along the axis of travel counts once, sideways twice, so "right"
        // prefers what is roughly on the same row.
        return candidates.min { a, b in
            cost(a.position, from: origin, direction) < cost(b.position, from: origin, direction)
        }?.id
    }

    private nonisolated func cost(_ p: GridPosition, from o: GridPosition, _ d: Direction) -> Int {
        let dr = abs(p.row - o.row), dc = abs(p.col - o.col)
        switch d {
        case .up, .down: return dr + 2 * dc
        case .left, .right: return dc + 2 * dr
        }
    }
}

#if os(tvOS)
extension Direction {
    init(_ move: MoveCommandDirection) {
        switch move {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        default: self = .right
        }
    }
}
#endif

#if os(macOS)
extension View {
    /// Routes board keys to `handle` while the board is on screen. Read from
    /// the window's event stream rather than SwiftUI focus: focus set on appear
    /// lands before the window is key and clicks never restore it, so a
    /// focus-based board drops every key (Numeriqo's first Mac build).
    func macBoardKeys(_ handle: @escaping (BoardKey) -> Bool) -> some View {
        modifier(BoardKeyMonitor(handle: handle))
    }
}

private struct BoardKeyMonitor: ViewModifier {
    let handle: (BoardKey) -> Bool
    @State private var monitor: Any?

    func body(content: Content) -> some View {
        content
            .onAppear {
                guard monitor == nil else { return }
                monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                    if event.window?.firstResponder is NSTextView { return event }
                    let flags = event.modifierFlags.intersection([.command, .control, .option])
                    guard let key = BoardKey.from(keyCode: event.keyCode,
                                                  characters: event.charactersIgnoringModifiers ?? "",
                                                  hasModifier: !flags.isEmpty)
                    else { return event }
                    return MainActor.assumeIsolated { handle(key) } ? nil : event
                }
            }
            .onDisappear {
                if let monitor { NSEvent.removeMonitor(monitor) }
                monitor = nil
            }
    }
}
#endif
