import SwiftUI
import Combine

// Game logic for the number guessing game. UI-agnostic state machine:
// setup -> playing -> won.
// v3.1: hot/cold proximity feedback, narrowed-range display, lifetime stats.
// v3.2: win streaks, daily-challenge fixed-seed mode.

/// Deterministic RNG (splitmix64) for the daily challenge: everyone who plays
/// on the same calendar day gets the same secret number. No dependencies.
struct SeededRNG {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    mutating func nextInt(in range: ClosedRange<Int>) -> Int {
        let span = UInt64(range.upperBound - range.lowerBound + 1)
        return range.lowerBound + Int(next() % span)
    }
}

final class GuessModel: ObservableObject {

    enum Phase { case setup, playing, won, lost }
    enum Tone { case neutral, low, high, error, win }

    /// How close the last guess was, as a fraction of the range.
    enum Proximity: CaseIterable {
        case freezing, cold, warm, hot, burning

        var label: String {
            switch self {
            case .freezing: return "Freezing — way off"
            case .cold: return "Cold"
            case .warm: return "Warm — getting there"
            case .hot: return "Hot!"
            case .burning: return "Burning hot!"
            }
        }

        var emoji: String {
            switch self {
            case .freezing: return "🧊"
            case .cold: return "❄️"
            case .warm: return "🌤️"
            case .hot: return "🔥"
            case .burning: return "🚀"
            }
        }
    }

    struct Attempt: Identifiable {
        let id = UUID()
        let value: Int
        let hint: Hint
        let number: Int

        enum Hint { case low, high, correct }
    }

    enum Difficulty: String, CaseIterable, Identifiable {
        case easy = "Easy"
        case medium = "Medium"
        case hard = "Hard"
        case custom = "Custom"

        var id: String { rawValue }

        /// Fixed range, or nil for custom.
        var range: (Int, Int)? {
            switch self {
            case .easy: return (1, 50)
            case .medium: return (1, 100)
            case .hard: return (1, 500)
            case .custom: return nil
            }
        }

        /// Max attempts before the round is lost, or nil for unlimited.
        var attemptLimit: Int? {
            switch self {
            case .easy: return 8
            case .medium: return 10
            case .hard: return 15
            case .custom: return nil
            }
        }
    }

    @Published var phase: Phase = .setup
    @Published var difficulty: Difficulty = .medium
    @Published var minText = "1"
    @Published var maxText = "100"
    @Published var guessText = ""
    @Published var attempts: [Attempt] = []
    @Published var message = "Pick a difficulty and press Start."
    @Published var tone: Tone = .neutral
    @Published var proximity: Proximity? = nil
    @Published var possibleLo = 1
    @Published var possibleHi = 100
    @Published var errorMessage: String? = nil
    @Published var best: Int? = nil
    @Published var isNewBest = false

    // Cryptic hints (HintEngine) — 3 per round, never name the number.
    @Published var shownHints: [String] = []
    private let maxHintsPerRound = 3

    var hintsLeft: Int { max(0, maxHintsPerRound - shownHints.count) }

    func askHint() {
        guard phase == .playing, hintsLeft > 0 else { return }
        let candidates = HintEngine.hintsFor(
            target: secret,
            guesses: attempts.map(\.value),
            lowerBound: lower,
            upperBound: upper
        )
        if let next = candidates.first(where: { !shownHints.contains($0) }) {
            shownHints.append(next)
        }
    }

    // Lifetime stats (all difficulties combined)
    @Published var gamesPlayed = 0
    @Published var gamesWon = 0
    @Published var totalAttempts = 0

    /// Consecutive wins, any mode. Persisted; reset on a loss.
    /// willSet publishes — @AppStorage alone doesn't emit objectWillChange.
    @AppStorage("gg3-guess-streak") var streak = 0 {
        willSet { objectWillChange.send() }
    }
    /// Daily challenge: fixed 1–100 range, 10 attempts, date-seeded secret.
    @Published var dailyMode = false

    var avgAttempts: Double {
        gamesWon > 0 ? Double(totalAttempts) / Double(gamesWon) : 0
    }

    var winRate: Double {
        gamesPlayed > 0 ? Double(gamesWon) / Double(gamesPlayed) : 0
    }

    /// Nil when the difficulty has no attempt cap.
    var attemptsLeft: Int? {
        guard let limit = currentAttemptLimit else { return nil }
        return max(0, limit - attempts.count)
    }

    /// Daily challenge always plays 1–100 with 10 attempts.
    var currentAttemptLimit: Int? {
        dailyMode ? 10 : difficulty.attemptLimit
    }

    /// yyyymmdd — the daily challenge seed. Same number for everyone, all day.
    private var dailySeed: UInt64 {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        let y = c.year ?? 0
        let m = c.month ?? 0
        let d = c.day ?? 0
        return UInt64(y * 10_000 + m * 100 + d)
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    var dailyDateLabel: String { Self.dayFormatter.string(from: Date()) }

    private var secret = 0
    private var lower = 1
    private var upper = 100

    var rangeLabel: String { "\(lower)–\(upper)" }

    init() {
        loadBest()
        loadStats()
    }

    // MARK: - Setup

    func selectDifficulty(_ d: Difficulty) {
        difficulty = d
        isNewBest = false
        if let r = d.range {
            minText = "\(r.0)"
            maxText = "\(r.1)"
        }
        loadBest()
    }

    func startGame() {
        let lo: Int
        let hi: Int
        if dailyMode {
            lo = 1
            hi = 100
        } else {
            lo = max(1, Int(minText) ?? 1)
            hi = max(lo + 1, Int(maxText) ?? 100)
        }
        lower = lo
        upper = hi
        possibleLo = lo
        possibleHi = hi
        minText = "\(lo)"
        maxText = "\(hi)"
        if dailyMode {
            var rng = SeededRNG(seed: dailySeed)
            secret = rng.nextInt(in: lo...hi)
        } else {
            secret = Int.random(in: lo...hi)
        }
        attempts = []
        shownHints = []
        guessText = ""
        errorMessage = nil
        proximity = nil
        isNewBest = false
        phase = .playing
        message = dailyMode
            ? "Daily challenge (\(dailyDateLabel)) — I'm thinking of a number between 1 and 100."
            : "I'm thinking of a number between \(lo) and \(hi)."
        tone = .neutral
    }

    // MARK: - Play

    func submitGuess() {
        guard phase == .playing else { return }
        guard let val = Int(guessText), !guessText.isEmpty else {
            showError("Enter a number first.")
            return
        }
        guard val >= lower && val <= upper else {
            showError("Guess must be between \(lower) and \(upper).")
            return
        }

        let n = attempts.count + 1
        if val == secret {
            attempts.append(Attempt(value: val, hint: .correct, number: n))
            phase = .won
            message = "Correct! The number was \(secret)."
            tone = .win
            proximity = nil
            streak += 1
            SoundFX.shared.play(.win)
            recordWin(attempts: n)
            if best == nil || n < best! {
                best = n
                isNewBest = true
                saveBest()
            }
        } else {
            let tooLow = val < secret
            attempts.append(Attempt(value: val, hint: tooLow ? .low : .high, number: n))
            if tooLow {
                possibleLo = max(possibleLo, val + 1)
                proximity = proximityFor(distance: secret - val)
                message = "\(val) is too low — try higher."
                tone = .low
            } else {
                possibleHi = min(possibleHi, val - 1)
                proximity = proximityFor(distance: val - secret)
                message = "\(val) is too high — try lower."
                tone = .high
            }
            // Out of attempts?
            if let left = attemptsLeft, left == 0 {
                phase = .lost
                message = "Out of attempts! The number was \(secret)."
                tone = .error
                proximity = nil
                streak = 0
                SoundFX.shared.play(.lose)
                recordLoss()
            }
        }
        guessText = ""
    }

    private func proximityFor(distance: Int) -> Proximity {
        let span = max(1, upper - lower)
        let ratio = Double(distance) / Double(span)
        switch ratio {
        case ..<0.04: return .burning
        case ..<0.12: return .hot
        case ..<0.28: return .warm
        case ..<0.55: return .cold
        default: return .freezing
        }
    }

    func quickPick(_ value: Int) {
        guard phase == .playing else { return }
        guessText = "\(value)"
        submitGuess()
    }

    var quickPicks: [(String, Int)] {
        let mid = (lower + upper) / 2
        let q1 = (lower + mid) / 2
        let q3 = (mid + upper) / 2
        return [("Min", lower), ("25%", q1), ("50%", mid), ("75%", q3), ("Max", upper)]
    }

    /// ⌘N / Play Again: same range, new secret.
    func playAgain() {
        startGame()
    }

    func backToSetup() {
        phase = .setup
        attempts = []
        shownHints = []
        guessText = ""
        errorMessage = nil
        proximity = nil
        isNewBest = false
        message = "Pick a difficulty and press Start."
        tone = .neutral
    }

    func resetForNewGameCommand() {
        if phase == .playing || phase == .won || phase == .lost {
            startGame()
        }
    }

    // MARK: - Best score (fewest attempts, per difficulty)

    private var bestKey: String { "gg3-best-\(difficulty.rawValue.lowercased())" }

    private func loadBest() {
        let v = UserDefaults.standard.integer(forKey: bestKey)
        best = v > 0 ? v : nil
    }

    private func saveBest() {
        if let b = best {
            UserDefaults.standard.set(b, forKey: bestKey)
        }
    }

    // MARK: - Lifetime stats

    private func loadStats() {
        gamesPlayed = UserDefaults.standard.integer(forKey: "gg3-guess-played")
        gamesWon = UserDefaults.standard.integer(forKey: "gg3-guess-won")
        totalAttempts = UserDefaults.standard.integer(forKey: "gg3-guess-attempts")
    }

    private func recordWin(attempts n: Int) {
        gamesPlayed += 1
        gamesWon += 1
        totalAttempts += n
        UserDefaults.standard.set(gamesPlayed, forKey: "gg3-guess-played")
        UserDefaults.standard.set(gamesWon, forKey: "gg3-guess-won")
        UserDefaults.standard.set(totalAttempts, forKey: "gg3-guess-attempts")
    }

    private func recordLoss() {
        gamesPlayed += 1
        UserDefaults.standard.set(gamesPlayed, forKey: "gg3-guess-played")
    }

    // MARK: - Errors (auto-dismissing)

    func showError(_ text: String) {
        errorMessage = text
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            if self?.errorMessage == text {
                self?.errorMessage = nil
            }
        }
    }

    func dismissError() {
        errorMessage = nil
    }
}
