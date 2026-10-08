import SwiftUI

// Snakes & Ladders — vs the CPU, or 2-player local pass-and-play.
// Roll the dice, hop along, climb ladders, dodge snakes.
// Exact roll needed to win on 100.

final class SnakesLaddersModel: ObservableObject {

    enum Turn { case player, cpu }

    static let ladders: [Int: Int] = [
        4: 25, 13: 46, 33: 49, 42: 63, 50: 69, 62: 81, 74: 92,
    ]
    static let snakes: [Int: Int] = [
        99: 41, 89: 53, 76: 58, 66: 45, 55: 25, 54: 34, 43: 18, 27: 5,
    ]

    @Published var playerPos = 1
    @Published var cpuPos = 1
    @Published var turn: Turn = .player
    @Published var diceValue = 1
    @Published var rolling = false
    @Published var winner: Turn? = nil
    @Published var message = "Your turn — tap the dice."
    @Published var playerWins = 0
    @Published var cpuWins = 0
    /// false = you vs CPU, true = two humans passing one Mac back and forth.
    @Published var twoPlayer = false

    /// Bumps on every newGame(); stale delayed callbacks bail when it mismatches.
    private var generation = 0

    init() {
        playerWins = UserDefaults.standard.integer(forKey: "gg3-ladders-pwins")
        cpuWins = UserDefaults.standard.integer(forKey: "gg3-ladders-cwins")
    }

    func newGame() {
        generation += 1
        playerPos = 1
        cpuPos = 1
        turn = .player
        diceValue = 1
        rolling = false
        winner = nil
        message = twoPlayer ? "Player 1's turn — tap the dice." : "Your turn — tap the dice."
    }

    func resetForNewGameCommand() { newGame() }

    /// Display name for a side, depending on the mode.
    func sideName(_ side: Turn) -> String {
        switch side {
        case .player: return twoPlayer ? "Player 1" : "You"
        case .cpu: return twoPlayer ? "Player 2" : "CPU"
        }
    }

    // MARK: - Rolling

    func rollDice() {
        guard !rolling, winner == nil else { return }
        // In vs-CPU mode the CPU rolls for itself; in 2P either human rolls.
        if turn == .cpu && !twoPlayer { return }
        startRoll(for: turn)
    }

    private func startRoll(for side: Turn) {
        rolling = true
        if side == .player {
            message = twoPlayer ? "Player 1 is rolling…" : "Rolling…"
        } else {
            message = twoPlayer ? "Player 2 is rolling…" : "CPU is rolling…"
        }
        SoundFX.shared.play(.dice)
        let gen = generation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
            guard let self, gen == self.generation else { return }
            self.rolling = false
            let roll = Int.random(in: 1...6)
            self.diceValue = roll
            self.message = "\(self.sideName(side)) rolled \(roll)."
            self.beginMove(side: side, steps: roll)
        }
    }

    private func beginMove(side: Turn, steps: Int) {
        let pos = side == .player ? playerPos : cpuPos
        if pos + steps > 100 {
            message = "Need exactly \(100 - pos) — no move."
            endTurn(after: side)
            return
        }
        var remaining = steps
        let gen = generation
        func hop() {
            guard gen == self.generation else { return }
            guard remaining > 0 else { self.finishMove(side: side); return }
            remaining -= 1
            if side == .player { self.playerPos += 1 } else { self.cpuPos += 1 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.16, execute: hop)
        }
        hop()
    }

    private func finishMove(side: Turn) {
        let pos = side == .player ? playerPos : cpuPos
        if pos == 100 {
            winner = side
            if twoPlayer {
                message = side == .player ? "PLAYER 1 WINS! 🏆" : "PLAYER 2 WINS! 🏆"
            } else {
                message = side == .player ? "YOU WIN! 🏆" : "CPU wins this one."
            }
            recordWin(side)
            SoundFX.shared.play(twoPlayer || side == .player ? .win : .lose)
            return
        }
        if let top = Self.ladders[pos] {
            message = "\(sideName(side)) climbed a ladder! 🪜 \(pos) → \(top)"
            let gen = generation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                guard let self, gen == self.generation else { return }
                if side == .player { self.playerPos = top } else { self.cpuPos = top }
                self.endTurn(after: side)
            }
            return
        }
        if let tail = Self.snakes[pos] {
            let snakeBit = (side == .player && !twoPlayer)
                ? "A snake got you!"
                : "A snake got \(sideName(side))!"
            message = "\(snakeBit) 🐍 \(pos) → \(tail)"
            let gen = generation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                guard let self, gen == self.generation else { return }
                if side == .player { self.playerPos = tail } else { self.cpuPos = tail }
                self.endTurn(after: side)
            }
            return
        }
        endTurn(after: side)
    }

    private func endTurn(after side: Turn) {
        guard winner == nil else { return }
        if side == .player {
            turn = .cpu
            if twoPlayer {
                message = "Player 2's turn — tap the dice."
            } else {
                let gen = generation
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    guard let self, gen == self.generation, self.winner == nil else { return }
                    self.startRoll(for: .cpu)
                }
            }
        } else {
            turn = .player
            message = twoPlayer ? "Player 1's turn — tap the dice." : "Your turn — tap the dice."
        }
    }

    private func recordWin(_ side: Turn) {
        if side == .player {
            playerWins += 1
            UserDefaults.standard.set(playerWins, forKey: "gg3-ladders-pwins")
        } else {
            cpuWins += 1
            UserDefaults.standard.set(cpuWins, forKey: "gg3-ladders-cwins")
        }
    }
}
