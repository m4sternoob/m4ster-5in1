import SwiftUI

// 2048 on macOS: slide and merge tiles with the arrow keys or the
// on-screen pad, chase the 2048 tile. Best score persists between runs.

final class Twenty48Model: ObservableObject {
    @Published var board = newTwenty48Board()
    @Published var score = 0
    @Published var isGameOver = false
    /// The hint arrow currently flashed over the board; nil most of the time.
    @Published var hintDirection: Twenty48Direction? = nil

    /// Persisted best score. willSet publishes — @AppStorage alone
    /// doesn't emit objectWillChange.
    @AppStorage("gg3-2048-best") var best = 0 {
        willSet { objectWillChange.send() }
    }

    /// Bumps on every newGame() and showHint(); a stale scheduled hint
    /// fade bails when it mismatches.
    private var generation = 0

    func newGame() {
        generation += 1
        bankScore()
        board = newTwenty48Board()
        score = 0
        isGameOver = false
        hintDirection = nil
    }

    func resetForNewGameCommand() { newGame() }

    func move(_ dir: Twenty48Direction) {
        guard !isGameOver else { return }
        hintDirection = nil
        let result = moveTwenty48(board, dir)
        guard result.moved else { return }
        let grown = spawnTwenty48Tile(result.board)
        board = grown
        score += result.gained
        if result.gained > 0 {
            SoundFX.shared.play(.eat)
        } else {
            SoundFX.shared.play(.tap)
        }
        if !canMoveTwenty48(grown) {
            isGameOver = true
            bankScore()
            SoundFX.shared.play(.lose)
        }
    }

    /// Flashes the roomiest move as an arrow over the board. The arrow
    /// fades after a beat so it reads as a nudge, not UI.
    func showHint() {
        guard !isGameOver, let dir = suggestTwenty48Move(board) else { return }
        generation += 1
        let gen = generation
        hintDirection = dir
        SoundFX.shared.play(.tap)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            guard let self, gen == self.generation else { return }
            self.hintDirection = nil
        }
    }

    /// The bank only keeps the high-water mark, so calling it twice is harmless.
    private func bankScore() {
        if score > best {
            best = score
        }
    }
}
