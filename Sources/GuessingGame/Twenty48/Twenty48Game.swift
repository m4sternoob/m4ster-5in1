// 2048: slide the 4x4 board, equal tiles merge, chase the 2048 tile.
// Pure board logic lives here so it stays easy to reason about; the
// model owns the game state. A board is 16 ints in row-major order,
// 0 is empty.

let twenty48GridSize = 4
private let twenty48Cells = twenty48GridSize * twenty48GridSize

enum Twenty48Direction: CaseIterable {
    case up, down, left, right
}

/// One swipe's outcome: the new board, the score gained from merges,
/// and whether anything actually moved (no move, no new tile).
struct Twenty48MoveResult {
    let board: [Int]
    let gained: Int
    let moved: Bool
}

/// Fresh board: two starting tiles.
func newTwenty48Board() -> [Int] {
    spawnTwenty48Tile(spawnTwenty48Tile(Array(repeating: 0, count: twenty48Cells)))
}

func moveTwenty48(_ board: [Int], _ dir: Twenty48Direction) -> Twenty48MoveResult {
    var next = board
    var gained = 0
    for line in twenty48Lines(for: dir) {
        let (merged, lineGained) = mergeTwenty48Line(line.map { board[$0] })
        gained += lineGained
        for (i, cell) in line.enumerated() {
            next[cell] = merged[i]
        }
    }
    return Twenty48MoveResult(board: next, gained: gained, moved: next != board)
}

/// The four cell-index lines in swipe order for a direction. Merging
/// always pulls toward the front of each line.
private func twenty48Lines(for dir: Twenty48Direction) -> [[Int]] {
    switch dir {
    case .left: return twenty48Rows()
    case .right: return twenty48Rows().map { Array($0.reversed()) }
    case .up: return twenty48Cols()
    case .down: return twenty48Cols().map { Array($0.reversed()) }
}

private func twenty48Rows() -> [[Int]] {
    (0..<twenty48GridSize).map { r in
        (0..<twenty48GridSize).map { c in r * twenty48GridSize + c }
    }
}

private func twenty48Cols() -> [[Int]] {
    (0..<twenty48GridSize).map { c in
        (0..<twenty48GridSize).map { r in r * twenty48GridSize + c }
    }
}

/// Slide one line toward its front: compact, merge each pair once,
/// compact again, pad with empties. Returns the line and points gained.
private func mergeTwenty48Line(_ line: [Int]) -> ([Int], Int) {
    var tiles = line.filter { $0 != 0 }
    var gained = 0
    var i = 0
    while i < tiles.count - 1 {
        if tiles[i] == tiles[i + 1] {
            tiles[i] *= 2
            gained += tiles[i]
            tiles.remove(at: i + 1)
        }
        i += 1
    }
    while tiles.count < twenty48GridSize {
        tiles.append(0)
    }
    return (tiles, gained)
}

/// Drop a 2 (90%) or 4 (10%) onto a random empty cell.
func spawnTwenty48Tile(_ board: [Int]) -> [Int] {
    let empty = board.indices.filter { board[$0] == 0 }
    guard let cell = empty.randomElement() else { return board }
    var next = board
    next[cell] = Double.random(in: 0..<1) < 0.9 ? 2 : 4
    return next
}

/// Any legal move left: an empty cell, or two equal neighbours.
func canMoveTwenty48(_ board: [Int]) -> Bool {
    if board.contains(0) { return true }
    for r in 0..<twenty48GridSize {
        for c in 0..<twenty48GridSize {
            let v = board[r * twenty48GridSize + c]
            if c + 1 < twenty48GridSize && board[r * twenty48GridSize + c + 1] == v {
                return true
            }
            if r + 1 < twenty48GridSize && board[(r + 1) * twenty48GridSize + c] == v {
                return true
            }
        }
    }
    return false
}

/// Hint: the move leaving the most open space, ties broken by score.
/// A fuller board after the move is a worse board. Nil when stuck.
func suggestTwenty48Move(_ board: [Int]) -> Twenty48Direction? {
    var best: Twenty48Direction? = nil
    var bestRank = Int.min
    for dir in Twenty48Direction.allCases {
        let result = moveTwenty48(board, dir)
        guard result.moved else { continue }
        let rank = result.board.filter { $0 == 0 }.count * 100 + result.gained
        if rank > bestRank {
            bestRank = rank
            best = dir
        }
    }
    return best
}
