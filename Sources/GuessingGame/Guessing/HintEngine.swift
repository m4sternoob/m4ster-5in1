// Cryptic hints for the number guessing game.
// Swift port of the Android HintEngine: hints never state the number
// outright — they describe it with wordplay, fun facts and math riddles.

enum HintEngine {

    /// What each digit looks like when you squint at it. Two variants each
    /// so hints feel fresh across rounds.
    private static let digitLooks: [Int: [String]] = [
        0: ["a round egg", "a cheerio"],
        1: ["a single straight stick", "a candle"],
        2: ["a graceful swan", "a curly wave"],
        3: ["two half-hearts stacked together", "a pair of lips turned sideways"],
        4: ["an open box", "a little flag on a pole"],
        5: ["a round belly wearing a flat hat", "a seahorse"],
        6: ["a zero with a curly tail", "a hook"],
        7: ["a bent corner, like an elbow", "a cliff edge"],
        8: ["a zero stacked on top of another zero", "a snowman"],
        9: ["a balloon on a straight string", "a zero with a stick leg"],
    ]

    /// Riddle-style associations for well-known numbers.
    private static let funFacts: [Int: String] = [
        1: "The loneliest number (ask Three Dog Night).",
        2: "A pair — like twins, or shoes.",
        3: "The Three Musketeers.",
        4: "Seasons in a year.",
        5: "Fingers on one hand.",
        6: "Sides of a dice.",
        7: "Lucky number — and days in a week.",
        9: "Lives of a cat.",
        10: "Fingers on both hands.",
        11: "Players of a football team on the pitch.",
        12: "Eggs in a dozen.",
        13: "The unlucky seat at the table.",
        14: "Say hi to my Valentine! (Cupid's big day.)",
        15: "Minutes in a quarter of an hour.",
        16: "Sweet sixteen.",
        18: "The age you can finally vote.",
        20: "Fingers and toes, all together.",
        21: "Blackjack!",
        22: "Two ducks, quack quack (a bingo call).",
        24: "Hours in a day.",
        25: "A quarter of a hundred.",
        26: "Letters in the alphabet.",
        30: "Days in an average month.",
        33: "A vinyl LP spins at this speed.",
        40: "Forty days and forty nights.",
        42: "The answer to life, the universe and everything.",
        50: "Half a century.",
        52: "Cards in a deck (jokers excluded).",
        60: "Seconds in a minute.",
        64: "Squares on a chessboard.",
        77: "Double sevens — a slot machine jackpot.",
        88: "Two fat ladies (a bingo call).",
        90: "Degrees in a right angle.",
        100: "A full century.",
    ]

    private static func isPrime(_ n: Int) -> Bool {
        if n < 2 { return false }
        if n % 2 == 0 { return n == 2 }
        var i = 3
        while i * i <= n {
            if n % i == 0 { return false }
            i += 2
        }
        return true
    }

    private static func isSquare(_ n: Int) -> Bool {
        let r = Int(Double(n).squareRoot())
        return r * r == n
    }

    /// Describes the digits visually, e.g. 8 -> "a zero stacked on top of
    /// another zero".
    private static func digitHint(_ n: Int) -> String {
        let digits = String(n).compactMap { $0.wholeNumberValue }
        let looks = digits.map { digitLooks[$0]?.randomElement() ?? "a mystery squiggle" }
        switch digits.count {
        case 1:
            return "Squint at it: it looks like \(looks[0])."
        case 2:
            return "Picture the digits: the first looks like \(looks[0]), the second like \(looks[1])."
        default:
            return "Picture the digits, one by one: \(looks.joined(separator: "; "))."
        }
    }

    /// Little math riddles that never name the number.
    private static func mathHint(_ n: Int) -> String {
        var parts: [String] = []
        parts.append(n % 2 == 0 ? "It's even." : "It's odd.")
        if let divisor = [3, 5, 7, 11].first(where: { n % $0 == 0 }) {
            parts.append("It's divisible by \(divisor).")
        }
        if isSquare(n) {
            parts.append("It's a square number — some whole number times itself.")
        } else if isPrime(n) {
            parts.append("It's prime — only 1 and itself divide it.")
        }
        let sum = String(n).compactMap { $0.wholeNumberValue }.reduce(0, +)
        // Skip the digit sum for single-digit targets — it would just be the number itself.
        if n >= 10 {
            parts.append("Its digits add up to \(sum).")
        }
        let digits = String(n)
        if digits.count == 2, digits.first == digits.last {
            parts.append("Both its digits are twins.")
        }
        return parts.prefix(2).joined(separator: " ")
    }

    /// All hint candidates for this round, fun first. The caller hands them
    /// out one at a time, skipping ones already shown.
    static func hintsFor(target: Int, guesses: [Int], lowerBound: Int, upperBound: Int) -> [String] {
        var out: [String] = []
        if let fact = funFacts[target] {
            out.append("Fun fact: \(fact)")
        }
        out.append(digitHint(target))
        out.append(mathHint(target))
        let wrong = guesses.filter { $0 != target }
        if !wrong.isEmpty {
            let lo = wrong.filter { $0 < target }.max() ?? lowerBound
            let hi = wrong.filter { $0 > target }.min() ?? upperBound
            if lo < hi {
                out.append("From your guesses so far: it's between \(lo) and \(hi).")
            }
        }
        // Deduplicate, keep order.
        var seen = Set<String>()
        return out.filter { seen.insert($0).inserted }
    }
}
