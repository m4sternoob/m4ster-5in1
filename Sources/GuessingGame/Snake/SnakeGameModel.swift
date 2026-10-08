import SwiftUI
import SpriteKit

// Snake game logic. The scene drives stepping via update(); the SwiftUI view
// feeds direction changes from keyboard or the on-screen pad.

enum SnakeDirection {
    case up, down, left, right
}

final class SnakeGameModel: ObservableObject {
    @Published var score = 0
    @Published var highScore = 0
    @Published var isGameOver = false
    @Published var isPaused = false
    /// Length and survival time of the last run — shown on the game-over card.
    @Published var finalLength = 0
    @Published var finalTime: TimeInterval = 0
    /// When true, the snake wraps around the edges instead of dying on walls.
    @Published var wrapMode = false
    /// Combo multiplier for chained quick pickups.
    @Published var combo = 1

    enum Speed: String, CaseIterable, Identifiable {
        case chill = "Chill"
        case normal = "Normal"
        case insane = "Insane"

        var id: String { rawValue }

        var stepInterval: TimeInterval {
            switch self {
            case .chill: return 0.16
            case .normal: return 0.12
            case .insane: return 0.07
            }
        }
    }

    @Published var speed: Speed = .normal {
        didSet { stepTime = speed.stepInterval }
    }

    let scene = SnakeScene()

    // Game state (owned by the model, rendered by the scene)
    var body: [(x: Int, y: Int)] = []
    var direction: SnakeDirection = .right
    var nextDirection: SnakeDirection = .right
    var foodX = -1
    var foodY = -1
    let gridSize = 20
    var accumulator: TimeInterval = 0
    var stepTime: TimeInterval = 0.12
    var foodPulse: TimeInterval = 0
    /// Wall-clock-ish play time, advanced by the scene each frame.
    var elapsed: TimeInterval = 0
    private var lastEatElapsed: TimeInterval = -10
    /// Set by step() when food is eaten; the scene consumes it to spawn FX.
    var justAte: EatEvent?

    struct EatEvent {
        let x: Int
        let y: Int
        let points: Int
        let combo: Int
    }

    init() {
        scene.gameModel = self
        loadHighScore()
        restart()
    }

    func setDirection(_ dir: SnakeDirection) {
        guard !isGameOver, !isPaused else { return }
        let isOpposite: Bool
        switch direction {
        case .up: isOpposite = (dir == .down)
        case .down: isOpposite = (dir == .up)
        case .left: isOpposite = (dir == .right)
        case .right: isOpposite = (dir == .left)
        }
        if !isOpposite {
            nextDirection = dir
        }
    }

    func togglePause() {
        if !isGameOver {
            isPaused.toggle()
            SoundFX.shared.play(.tap)
        }
    }

    func restart() {
        body = []
        let startX = gridSize / 2
        let startY = gridSize / 2
        for i in 0..<3 {
            body.append((startX - i, startY))
        }
        direction = .right
        nextDirection = .right
        score = 0
        combo = 1
        elapsed = 0
        lastEatElapsed = -10
        justAte = nil
        isGameOver = false
        isPaused = false
        finalLength = 0
        finalTime = 0
        accumulator = 0
        stepTime = speed.stepInterval
        foodPulse = 0
        spawnFood()
    }

    func step() {
        direction = nextDirection

        let head = body[0]
        var newHead = head
        // SpriteKit is y-up: model y=0 is the bottom row, so moving up
        // means increasing y.
        switch direction {
        case .up: newHead.y += 1
        case .down: newHead.y -= 1
        case .left: newHead.x -= 1
        case .right: newHead.x += 1
        }

        // Wall collision — or wrap around the edges in wrap mode.
        if wrapMode {
            newHead.x = (newHead.x + gridSize) % gridSize
            newHead.y = (newHead.y + gridSize) % gridSize
        } else if newHead.x < 0 || newHead.x >= gridSize || newHead.y < 0 || newHead.y >= gridSize {
            gameOver()
            return
        }

        let willGrow = (newHead.x == foodX && newHead.y == foodY)

        // Self collision — the tail cell frees up this step, so skip it unless growing.
        let solidBody = willGrow ? body[...] : body.dropLast()
        for segment in solidBody where segment.x == newHead.x && segment.y == newHead.y {
            gameOver()
            return
        }

        body.insert(newHead, at: 0)

        if willGrow {
            // Combo: eat again within 2.5s to multiply the points.
            if elapsed - lastEatElapsed < 2.5 {
                combo += 1
            } else {
                combo = 1
            }
            lastEatElapsed = elapsed
            let points = 10 * combo
            score += points
            justAte = EatEvent(x: newHead.x, y: newHead.y, points: points, combo: combo)
            SoundFX.shared.play(.eat)
            if score % 50 == 0 && stepTime > 0.05 {
                stepTime *= 0.9 // speed up as you eat
            }
            spawnFood()
        } else {
            body.removeLast()
        }
    }

    func spawnFood() {
        for _ in 0..<100 {
            let candidate = (Int.random(in: 0..<gridSize), Int.random(in: 0..<gridSize))
            let occupied = body.contains { $0.x == candidate.0 && $0.y == candidate.1 }
            if !occupied {
                foodX = candidate.0
                foodY = candidate.1
                foodPulse = 0
                return
            }
        }
        foodX = gridSize / 2
        foodY = gridSize / 2
        foodPulse = 0
    }

    private func gameOver() {
        isGameOver = true
        finalLength = body.count
        finalTime = elapsed
        SoundFX.shared.play(.lose)
        if score > highScore {
            highScore = score
            saveHighScore()
        }
    }

    private func loadHighScore() {
        highScore = UserDefaults.standard.integer(forKey: "gg3-snake-highscore")
    }

    private func saveHighScore() {
        UserDefaults.standard.set(highScore, forKey: "gg3-snake-highscore")
    }
}
