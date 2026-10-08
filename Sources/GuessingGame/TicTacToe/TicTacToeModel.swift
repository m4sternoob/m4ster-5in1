import SwiftUI

// Tic-Tac-Toe — you (X) vs the CPU (O). Easy = random, Hard = minimax (unbeatable).

final class TicTacToeModel: ObservableObject {

    enum Cell: String { case empty = "", x = "X", o = "O" }
    enum Difficulty: String, CaseIterable, Identifiable {
        case easy = "Easy", hard = "Hard"
        var id: String { rawValue }
    }

    @Published var board = Array(repeating: Cell.empty, count: 9)
    @Published var difficulty: Difficulty = .hard
    @Published var winner: Cell? = nil
    @Published var isDraw = false
    @Published var winningLine: [Int]? = nil
    @Published var message = "Your turn — you're X."
    @Published var playerScore = 0
    @Published var cpuScore = 0
    @Published var draws = 0
    /// True while the CPU's move is scheduled but not yet played — drives the
    /// animated "thinking" indicator.
    @Published var cpuThinking = false
    /// Consecutive player wins. Persisted; a loss or draw resets it.
    /// willSet publishes — @AppStorage alone doesn't emit objectWillChange.
    @AppStorage("gg3-ttt-streak") var playerStreak = 0 {
        willSet { objectWillChange.send() }
    }

    /// Bumps on every newGame(); a stale scheduled CPU move bails when it mismatches.
    private var generation = 0

    var gameOver: Bool { winner != nil || isDraw }

    init() {
        playerScore = UserDefaults.standard.integer(forKey: "gg3-ttt-player")
        cpuScore = UserDefaults.standard.integer(forKey: "gg3-ttt-cpu")
        draws = UserDefaults.standard.integer(forKey: "gg3-ttt-draws")
    }

    func newGame() {
        generation += 1
        board = Array(repeating: Cell.empty, count: 9)
        winner = nil
        isDraw = false
        winningLine = nil
        cpuThinking = false
        message = "Your turn — you're X."
    }

    func setDifficulty(_ d: Difficulty) {
        difficulty = d
        newGame()
    }

    func resetForNewGameCommand() { newGame() }

    func tap(_ i: Int) {
        // Ignore taps while the CPU's move is still scheduled — otherwise a
        // fast second tap lands two Xs in one turn (and queues a second CPU
        // move on top of it).
        guard board[i] == .empty, !gameOver, !cpuThinking else { return }
        board[i] = .x
        SoundFX.shared.play(.tap)
        afterMove()
        if !gameOver {
            cpuThinking = true
            let gen = generation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
                guard let self, gen == self.generation else { return }
                self.cpuMove()
            }
        }
    }

    // MARK: - Rules

    private func afterMove() {
        if let line = Self.winLine(board) {
            winner = board[line[0]]
            winningLine = line
            message = winner == .x ? "You win! 🎉" : "CPU wins."
            recordResult()
        } else if !board.contains(.empty) {
            isDraw = true
            message = "It's a draw."
            recordResult()
        } else {
            message = board.filter({ $0 != .empty }).count % 2 == 0
                ? "Your turn — you're X."
                : "CPU is thinking…"
        }
    }

    private func cpuMove() {
        cpuThinking = false
        guard !gameOver else { return }
        let empties = board.indices.filter { board[$0] == .empty }
        guard let pick = empties.randomElement() else { return }
        let i: Int
        switch difficulty {
        case .easy:
            i = pick
        case .hard:
            i = bestMove()
        }
        board[i] = .o
        afterMove()
    }

    static func winLine(_ b: [Cell]) -> [Int]? {
        let lines = [[0,1,2],[3,4,5],[6,7,8],
                     [0,3,6],[1,4,7],[2,5,8],
                     [0,4,8],[2,4,6]]
        for l in lines where b[l[0]] != .empty && b[l[0]] == b[l[1]] && b[l[1]] == b[l[2]] {
            return l
        }
        return nil
    }

    // MARK: - Minimax (unbeatable)

    private func bestMove() -> Int {
        var b = board
        var bestScore = Int.min
        var move = b.firstIndex(of: .empty) ?? 0
        for i in 0..<9 where b[i] == .empty {
            b[i] = .o
            let score = minimax(&b, isMax: false, depth: 0)
            b[i] = .empty
            if score > bestScore {
                bestScore = score
                move = i
            }
        }
        return move
    }

    /// +10 for a CPU win, -10 for a player win, 0 for draw — depth-adjusted
    /// so the CPU prefers faster wins and slower losses.
    private func minimax(_ b: inout [Cell], isMax: Bool, depth: Int) -> Int {
        if let line = Self.winLine(b) {
            return b[line[0]] == .o ? 10 - depth : depth - 10
        }
        if !b.contains(.empty) { return 0 }
        if isMax {
            var best = Int.min
            for i in 0..<9 where b[i] == .empty {
                b[i] = .o
                best = max(best, minimax(&b, isMax: false, depth: depth + 1))
                b[i] = .empty
            }
            return best
        } else {
            var best = Int.max
            for i in 0..<9 where b[i] == .empty {
                b[i] = .x
                best = min(best, minimax(&b, isMax: true, depth: depth + 1))
                b[i] = .empty
            }
            return best
        }
    }

    // MARK: - Scores

    private func recordResult() {
        if winner == .x {
            playerScore += 1
            playerStreak += 1
            UserDefaults.standard.set(playerScore, forKey: "gg3-ttt-player")
            SoundFX.shared.play(.win)
        } else if winner == .o {
            cpuScore += 1
            playerStreak = 0
            UserDefaults.standard.set(cpuScore, forKey: "gg3-ttt-cpu")
            SoundFX.shared.play(.lose)
        } else {
            draws += 1
            playerStreak = 0
            UserDefaults.standard.set(draws, forKey: "gg3-ttt-draws")
        }
    }
}
