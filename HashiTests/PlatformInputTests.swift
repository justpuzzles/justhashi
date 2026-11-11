import Foundation
import Testing
@testable import Hashi

/// Mac keyboard and Apple TV remote play: what a key means, and where the
/// cursor goes when it moves.
@Suite("Keyboard and remote input")
@MainActor
struct PlatformInputTests {

    @Test func keyCodesMap() {
        #expect(BoardKey.from(keyCode: 126, characters: "", hasModifier: false) == .arrow(.up))
        #expect(BoardKey.from(keyCode: 124, characters: "", hasModifier: false) == .arrow(.right))
        #expect(BoardKey.from(keyCode: 49, characters: " ", hasModifier: false) == .pick)
        #expect(BoardKey.from(keyCode: 36, characters: "\r", hasModifier: false) == .pick)
        #expect(BoardKey.from(keyCode: 53, characters: "\u{1B}", hasModifier: false) == .drop)
        // Anything with a modifier belongs to the menu bar.
        #expect(BoardKey.from(keyCode: 126, characters: "", hasModifier: true) == nil)
        #expect(BoardKey.from(keyCode: 0, characters: "a", hasModifier: false) == nil)
    }

    /// Wherever there is a corridor, the cursor follows it: that is where a
    /// bridge from this island could go.
    @Test func theCursorFollowsACorridorWhenThereIsOne() {
        for puzzle in [Fixtures.square, Fixtures.crossing, Fixtures.chain] {
            for island in puzzle.islands {
                for direction in Direction.allCases {
                    if let edge = puzzle.edge(from: island.id, direction: direction) {
                        #expect(puzzle.neighbour(of: island.id, toward: direction)
                                == puzzle.edges[edge].other(island.id))
                    }
                }
            }
        }
    }

    /// Without a corridor it still moves the right way, so no island is out
    /// of the cursor's reach; at the edge of the board it stays put.
    @Test func theCursorAlwaysMovesTheWayItWasPressed() {
        for puzzle in [Fixtures.square, Fixtures.crossing, Fixtures.chain, Fixtures.fullCorners] {
            for island in puzzle.islands {
                let o = island.position
                for direction in Direction.allCases {
                    guard let next = puzzle.neighbour(of: island.id, toward: direction) else { continue }
                    let p = puzzle.islands[next].position
                    switch direction {
                    case .up: #expect(p.row < o.row)
                    case .down: #expect(p.row > o.row)
                    case .left: #expect(p.col < o.col)
                    case .right: #expect(p.col > o.col)
                    }
                }
            }
        }
    }

    @Test func everyIslandIsReachableFromTheFirst() {
        for puzzle in [Fixtures.square, Fixtures.crossing, Fixtures.chain, Fixtures.fullCorners] {
            var seen: Set<Int> = [0], queue = [0]
            while let island = queue.popLast() {
                for direction in Direction.allCases {
                    if let next = puzzle.neighbour(of: island, toward: direction), seen.insert(next).inserted {
                        queue.append(next)
                    }
                }
            }
            #expect(seen.count == puzzle.islands.count)
        }
    }
}
