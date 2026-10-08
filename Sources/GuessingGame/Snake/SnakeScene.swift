import SpriteKit

// Renders the snake model at 60fps. Pure rendering — all rules live in the model.
// v3.1: persistent FX layer (score popups, eat particles), death shake.

final class SnakeScene: SKScene {
    weak var gameModel: SnakeGameModel?

    private var lastUpdateTime: TimeInterval = 0
    private var cellSize: CGFloat = 0
    private var gridOffset = CGPoint.zero
    private var wasGameOver = false

    /// Game nodes are rebuilt every frame inside this layer…
    private let boardLayer = SKNode()
    /// …while transient juice (popups, particles) lives here untouched.
    private let fxLayer = SKNode()

    private let gridCount = 20
    private let gridBackground = SKColor(red: 0.04, green: 0.05, blue: 0.06, alpha: 1.0)
    private let gridLine = SKColor(red: 0.10, green: 0.11, blue: 0.14, alpha: 1.0)
    private let headColor = SKColor(red: 0.24, green: 0.86, blue: 0.39, alpha: 1.0)
    private let foodColor = SKColor(red: 1.0, green: 0.31, blue: 0.31, alpha: 1.0)
    private let foodGlow = SKColor(red: 1.0, green: 0.71, blue: 0.71, alpha: 0.8)

    override func didMove(to view: SKView) {
        backgroundColor = .clear
        // The scene must track the real view size — SpriteKit does not do this
        // automatically, and a zero-size scene renders nothing.
        scaleMode = .resizeFill
        size = view.bounds.size
        calculateLayout(for: size)
        addChild(boardLayer)
        addChild(fxLayer)
    }

    override func didChangeSize(_ oldSize: CGSize) {
        calculateLayout(for: size)
    }

    private func calculateLayout(for viewSize: CGSize) {
        let padding: CGFloat = 16
        let available = min(viewSize.width, viewSize.height) - padding * 2
        cellSize = available / CGFloat(gridCount)
        let gridLength = cellSize * CGFloat(gridCount)
        gridOffset = CGPoint(
            x: (viewSize.width - gridLength) / 2,
            y: (viewSize.height - gridLength) / 2
        )
    }

    override func update(_ currentTime: TimeInterval) {
        guard let model = gameModel else { return }

        if model.isGameOver {
            if !wasGameOver {
                wasGameOver = true
                shakeBoard()
            }
            // Keep the clock fresh while the game-over card is up: otherwise
            // the first frame after Restart sees a huge delta and the snake
            // burns through dozens of steps at once.
            lastUpdateTime = currentTime
            return
        }
        wasGameOver = false

        let delta: TimeInterval
        if lastUpdateTime == 0 {
            delta = 0
        } else {
            delta = currentTime - lastUpdateTime
        }
        lastUpdateTime = currentTime
        // Paused frames still advance the clock (above) but skip stepping, so
        // resuming never replays the paused time as snake movement.
        guard !model.isPaused else { return }

        model.accumulator += delta
        while model.accumulator >= model.stepTime {
            model.accumulator -= model.stepTime
            model.step()
        }
        model.foodPulse += delta * 3.0
        model.elapsed += delta

        if let event = model.justAte {
            model.justAte = nil
            spawnEatFX(event)
        }
    }

    override func didEvaluateActions() {
        render()
    }

    // MARK: - Juice

    private func cellCenter(x: Int, y: Int) -> CGPoint {
        CGPoint(
            x: gridOffset.x + CGFloat(x) * cellSize + cellSize / 2,
            y: gridOffset.y + CGFloat(y) * cellSize + cellSize / 2
        )
    }

    private func spawnEatFX(_ event: SnakeGameModel.EatEvent) {
        let center = cellCenter(x: event.x, y: event.y)

        let popup = SKLabelNode(text: "+\(event.points)")
        popup.fontSize = 17
        popup.fontName = "Helvetica-Bold"
        popup.fontColor = .white
        popup.position = center
        popup.run(.sequence([
            .group([.moveBy(x: 0, y: 34, duration: 0.55), .fadeOut(withDuration: 0.55)]),
            .removeFromParent(),
        ]))
        fxLayer.addChild(popup)

        if event.combo > 1 {
            let comboLabel = SKLabelNode(text: "COMBO ×\(event.combo)")
            comboLabel.fontSize = 13
            comboLabel.fontName = "Helvetica-Bold"
            comboLabel.fontColor = SKColor(red: 1.0, green: 0.72, blue: 0.25, alpha: 1.0)
            comboLabel.position = CGPoint(x: center.x, y: center.y - 18)
            comboLabel.run(.sequence([
                .group([.moveBy(x: 0, y: 26, duration: 0.6), .fadeOut(withDuration: 0.6)]),
                .removeFromParent(),
            ]))
            fxLayer.addChild(comboLabel)
        }

        for _ in 0..<10 {
            let dot = SKShapeNode(circleOfRadius: 3)
            dot.fillColor = headColor
            dot.strokeColor = .clear
            dot.position = center
            let angle = CGFloat.random(in: 0..<(2 * .pi))
            let dist = CGFloat.random(in: 24...52)
            dot.run(.sequence([
                .group([
                    .moveBy(x: cos(angle) * dist, y: sin(angle) * dist, duration: 0.4),
                    .fadeOut(withDuration: 0.4),
                ]),
                .removeFromParent(),
            ]))
            fxLayer.addChild(dot)
        }
    }

    private func shakeBoard() {
        let shake = SKAction.sequence([
            .moveBy(x: 9, y: 0, duration: 0.05),
            .moveBy(x: -18, y: 0, duration: 0.05),
            .moveBy(x: 18, y: 0, duration: 0.05),
            .moveBy(x: -9, y: 0, duration: 0.05),
        ])
        boardLayer.run(shake)
    }

    // MARK: - Board rendering

    private func render() {
        boardLayer.removeAllChildren()
        guard let model = gameModel, cellSize > 0 else { return }

        let gridRect = CGRect(
            x: gridOffset.x,
            y: gridOffset.y,
            width: cellSize * CGFloat(gridCount),
            height: cellSize * CGFloat(gridCount)
        )

        let bg = SKShapeNode(rect: gridRect, cornerRadius: 8)
        bg.fillColor = gridBackground
        bg.strokeColor = .clear
        boardLayer.addChild(bg)

        // Grid lines
        for i in 0...gridCount {
            let p = CGMutablePath()
            p.move(to: CGPoint(x: gridOffset.x + CGFloat(i) * cellSize, y: gridOffset.y))
            p.addLine(to: CGPoint(x: gridOffset.x + CGFloat(i) * cellSize, y: gridOffset.y + gridRect.height))
            let line = SKShapeNode(path: p)
            line.strokeColor = gridLine
            line.lineWidth = 1
            boardLayer.addChild(line)

            let q = CGMutablePath()
            q.move(to: CGPoint(x: gridOffset.x, y: gridOffset.y + CGFloat(i) * cellSize))
            q.addLine(to: CGPoint(x: gridOffset.x + gridRect.width, y: gridOffset.y + CGFloat(i) * cellSize))
            let line2 = SKShapeNode(path: q)
            line2.strokeColor = gridLine
            line2.lineWidth = 1
            boardLayer.addChild(line2)
        }

        // Food with pulse
        if model.foodX >= 0, model.foodY >= 0 {
            let pulse = 1.0 + 0.15 * sin(model.foodPulse * 4.0)
            let radius = cellSize * 0.35 * pulse
            let center = cellCenter(x: model.foodX, y: model.foodY)
            let glow = SKShapeNode(circleOfRadius: radius)
            glow.position = center
            glow.fillColor = foodGlow
            glow.strokeColor = .clear
            boardLayer.addChild(glow)

            let food = SKShapeNode(circleOfRadius: radius * 0.7)
            food.position = center
            food.fillColor = foodColor
            food.strokeColor = .clear
            boardLayer.addChild(food)
        }

        // Snake
        for (index, segment) in model.body.enumerated() {
            let rect = CGRect(
                x: gridOffset.x + CGFloat(segment.x) * cellSize + 1,
                y: gridOffset.y + CGFloat(segment.y) * cellSize + 1,
                width: cellSize - 2,
                height: cellSize - 2
            )
            let node = SKShapeNode(rect: rect, cornerRadius: index == 0 ? 6 : 4)
            if index == 0 {
                node.fillColor = headColor
            } else {
                let t = Double(index) / Double(max(model.body.count, 1))
                node.fillColor = SKColor(
                    red: 0.16 + 0.55 * (1.0 - t),
                    green: 0.71 + 0.15 * (1.0 - t),
                    blue: 0.27 + 0.07 * (1.0 - t),
                    alpha: 1.0
                )
            }
            node.strokeColor = .clear
            boardLayer.addChild(node)

            if index == 0 {
                drawEyes(on: node, in: rect)
            }
        }

        // Overlays
        if model.isGameOver {
            dimGrid(gridRect)
            addLabel("GAME OVER", at: CGPoint(x: frame.midX, y: frame.midY + 20),
                     size: 28, color: SKColor(red: 1.0, green: 0.31, blue: 0.31, alpha: 1.0))
            addLabel("Final Score: \(model.score)", at: CGPoint(x: frame.midX, y: frame.midY - 15),
                     size: 20, color: SKColor(red: 0.78, green: 0.78, blue: 0.86, alpha: 1.0))
        } else if model.isPaused {
            dimGrid(gridRect)
            addLabel("PAUSED", at: CGPoint(x: frame.midX, y: frame.midY),
                     size: 28, color: SKColor(red: 1.0, green: 0.78, blue: 0.31, alpha: 1.0))
        }
    }

    private func drawEyes(on node: SKShapeNode, in rect: CGRect) {
        // Note: the head node sits at (0,0), so board-space coordinates are
        // correct for its children.
        let eyeRadius: CGFloat = 3.0
        let eyeY: CGFloat
        var eyeX1 = rect.minX + rect.width * 0.3
        var eyeX2 = rect.minX + rect.width * 0.7
        switch gameModel?.direction {
        case .left:
            eyeX1 = rect.minX + rect.width * 0.2
            eyeX2 = rect.minX + rect.width * 0.6
            eyeY = rect.minY + rect.height * 0.35
        case .right:
            eyeX1 = rect.minX + rect.width * 0.4
            eyeX2 = rect.minX + rect.width * 0.8
            eyeY = rect.minY + rect.height * 0.35
        case .up:
            eyeY = rect.minY + rect.height * 0.75
        case .down:
            eyeY = rect.minY + rect.height * 0.25
        case .none:
            eyeY = rect.minY + rect.height * 0.35
        }
        for x in [eyeX1, eyeX2] {
            let eye = SKShapeNode(circleOfRadius: eyeRadius)
            eye.position = CGPoint(x: x, y: eyeY)
            eye.fillColor = .white
            eye.strokeColor = .clear
            node.addChild(eye)
        }
    }

    private func dimGrid(_ rect: CGRect) {
        let overlay = SKShapeNode(rect: rect, cornerRadius: 8)
        overlay.fillColor = SKColor(red: 0, green: 0, blue: 0, alpha: 0.7)
        overlay.strokeColor = .clear
        boardLayer.addChild(overlay)
    }

    private func addLabel(_ text: String, at position: CGPoint, size: CGFloat, color: SKColor) {
        let label = SKLabelNode(text: text)
        label.fontSize = size
        label.fontColor = color
        label.position = position
        label.verticalAlignmentMode = .center
        boardLayer.addChild(label)
    }
}
