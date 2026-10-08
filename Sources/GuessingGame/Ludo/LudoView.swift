import SwiftUI

// Ludo board — you (red) vs the CPU(s). Glowing tokens are movable: tap one.
// You vs CPU, or you vs 3 CPUs, with a fast-CPU animation toggle.

struct LudoView: View {
    @StateObject private var model = LudoModel()
    @EnvironmentObject private var coordinator: GameCoordinator

    private func color(for side: LudoModel.Side) -> Color {
        switch side {
        case .you: return Color(red: 0.95, green: 0.28, blue: 0.28)
        case .cpu1: return Color(red: 1.0, green: 0.80, blue: 0.20)
        case .cpu2: return Color(red: 0.25, green: 0.80, blue: 0.35)
        case .cpu3: return Color(red: 0.35, green: 0.60, blue: 1.0)
        }
    }

    private func baseOrigin(for side: LudoModel.Side) -> (r: Int, c: Int) {
        switch side {
        case .you: return (0, 0)
        case .cpu1: return (0, 9)
        case .cpu2: return (9, 0)
        case .cpu3: return (9, 9)
        }
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                header

                Divider()
                    .background(Theme.divider)

                board
                    .padding(14)

                controlsRow

                HStack(spacing: 20) {
                    DiceView(
                        value: model.diceValue,
                        rolling: model.rolling,
                        enabled: model.diceEnabled,
                        onTap: { model.rollDice() }
                    )

                    VStack(alignment: .leading, spacing: 6) {
                        Text(model.message)
                            .font(.headline)
                            .foregroundColor(Theme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 8) {
                            ForEach(model.activeSides, id: \.self) { side in
                                turnDot(isActive: model.turn == side,
                                        color: color(for: side),
                                        label: side.displayName)
                            }
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 8)

                if model.winner != nil {
                    winCard
                }

                Spacer(minLength: 8)
        }
        if model.winner == .you {
            ConfettiView()
        }
        }
        .onChange(of: coordinator.newGameID) { _, _ in
            model.resetForNewGameCommand()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Ludo")
                    .font(.title2.bold())
                    .foregroundColor(Theme.textPrimary)
                Text("Roll 6 to leave base • captures send tokens home")
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
            }
            Spacer()
            StatPill(icon: "person.fill", text: "You \(model.youWins)")
            StatPill(icon: "cpu", text: "CPU \(model.cpuWins)")
            Button(action: { model.newGame() }) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.title3)
                    .foregroundColor(.white)
                    .padding(10)
                    .background(Theme.surface2)
                    .cornerRadius(10)
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
    }

    private var controlsRow: some View {
        HStack {
            Picker("Players", selection: $model.fourPlayer) {
                Text("vs CPU").tag(false)
                Text("vs 3 CPU").tag(true)
            }
            .pickerStyle(.segmented)
            .frame(width: 190)
            .onChange(of: model.fourPlayer) { _, _ in model.newGame() }
            Toggle("Fast CPU", isOn: $model.fastCPU)
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)
                .toggleStyle(.switch)
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 6)
    }

    private func turnDot(isActive: Bool, color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
                .opacity(isActive ? 1 : 0.3)
            Text(label)
                .font(.subheadline)
                .foregroundColor(isActive ? Theme.textPrimary : Theme.textMuted)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(isActive ? Theme.surface2 : Color.clear)
        .cornerRadius(8)
        .animation(.easeInOut(duration: 0.2), value: isActive)
    }

    // MARK: - Board

    private var board: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let cell = size / 15
            ZStack {
                Canvas { context, canvasSize in
                    drawBoard(context: &context, size: canvasSize.width)
                }
                .frame(width: size, height: size)
                tokensOverlay(cell: cell, size: size)
            }
            .frame(width: size, height: size)
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: 500, maxHeight: 500)
    }

    private func drawBoard(context: inout GraphicsContext, size: CGFloat) {
        let cell = size / 15
        func rect(_ r: Int, _ c: Int) -> CGRect {
            CGRect(x: CGFloat(c) * cell, y: CGFloat(r) * cell, width: cell, height: cell)
        }

        // Background
        context.fill(Path(CGRect(x: 0, y: 0, width: size, height: size)),
                     with: .color(Color(red: 0.07, green: 0.08, blue: 0.11)))

        // Bases for the sides in play
        for side in model.activeSides {
            drawBase(context: &context, at: baseOrigin(for: side),
                     color: color(for: side), cell: cell)
        }

        // Main track — start squares take their side's color
        let startColor = Dictionary(
            uniqueKeysWithValues: model.activeSides.map { (LudoModel.startIndex[$0]!, $0) })
        for (i, p) in LudoModel.mainPath.enumerated() {
            var fill = Color(red: 0.14, green: 0.16, blue: 0.21)
            if let side = startColor[i] {
                fill = color(for: side)
            } else if LudoModel.safe.contains(i) {
                fill = Color(red: 0.20, green: 0.23, blue: 0.30)
            }
            context.fill(Path(rect(p.r, p.c).insetBy(dx: 0.5, dy: 0.5)), with: .color(fill))
            if LudoModel.safe.contains(i), startColor[i] == nil {
                let t = Text("★").font(.system(size: cell * 0.42)).foregroundColor(.white.opacity(0.75))
                context.draw(t, at: CGPoint(x: (CGFloat(p.c) + 0.5) * cell, y: (CGFloat(p.r) + 0.5) * cell),
                             anchor: .center)
            }
        }

        // Home stretches for the sides in play
        for side in model.activeSides {
            let col = color(for: side)
            for p in LudoModel.homeStretch[side]! {
                context.fill(Path(rect(p.r, p.c).insetBy(dx: 0.5, dy: 0.5)), with: .color(col.opacity(0.85)))
            }
        }

        // Center home
        let sides = model.activeSides
        let quadrants: [(ClosedRange<Int>, ClosedRange<Int>, Color)]
        if sides.count == 2 {
            quadrants = [
                (6...7, 6...7, color(for: .you)), (6...7, 7...8, color(for: .cpu1)),
                (7...8, 6...7, color(for: .you).opacity(0.7)), (7...8, 7...8, color(for: .cpu1).opacity(0.7)),
            ]
        } else {
            quadrants = [
                (6...7, 6...7, color(for: .you)), (6...7, 7...8, color(for: .cpu1)),
                (7...8, 6...7, color(for: .cpu2)), (7...8, 7...8, color(for: .cpu3)),
            ]
        }
        for (rs, cs, col) in quadrants {
            let q = CGRect(x: CGFloat(cs.lowerBound) * cell, y: CGFloat(rs.lowerBound) * cell,
                           width: CGFloat(cs.upperBound - cs.lowerBound + 1) * cell,
                           height: CGFloat(rs.upperBound - rs.lowerBound + 1) * cell)
            context.fill(Path(q.insetBy(dx: 0.5, dy: 0.5)), with: .color(col))
        }
    }

    private func drawBase(context: inout GraphicsContext, at origin: (r: Int, c: Int), color: Color, cell: CGFloat) {
        let outer = CGRect(x: CGFloat(origin.c) * cell, y: CGFloat(origin.r) * cell,
                           width: 6 * cell, height: 6 * cell)
        context.fill(RoundedRectangle(cornerRadius: 10).path(in: outer), with: .color(color))
        let inner = outer.insetBy(dx: cell * 0.7, dy: cell * 0.7)
        context.fill(RoundedRectangle(cornerRadius: 8).path(in: inner),
                     with: .color(Color(red: 0.10, green: 0.11, blue: 0.15)))
        for (sr, sc) in [(1.5, 1.5), (1.5, 3.5), (3.5, 1.5), (3.5, 3.5)] as [(CGFloat, CGFloat)] {
            let spot = CGRect(x: (CGFloat(origin.c) + sr) * cell, y: (CGFloat(origin.r) + sc) * cell,
                              width: cell, height: cell)
            context.fill(Ellipse().path(in: spot), with: .color(.white.opacity(0.9)))
            context.stroke(Ellipse().path(in: spot), with: .color(color), lineWidth: 2)
        }
    }

    // MARK: - Tokens

    private struct TokenSpot: Identifiable {
        let id: String
        let side: LudoModel.Side
        let index: Int
        let point: CGPoint
        let isMovable: Bool
    }

    private func tokenSpots(cell: CGFloat) -> [TokenSpot] {
        var spots: [TokenSpot] = []
        // Group on-board tokens by cell for stacking offsets.
        var byCell: [String: [Int]] = [:] // key -> token global ids
        func key(_ r: Int, _ c: Int) -> String { "\(r)-\(c)" }

        let sides = model.activeSides
        for (si, side) in sides.enumerated() {
            for (i, steps) in model.tokens[side]!.enumerated() {
                let gid = si * 4 + i
                if steps == -1 {
                    let o = baseOrigin(for: side)
                    let offs: (CGFloat, CGFloat) = [(1.5, 1.5), (1.5, 3.5), (3.5, 1.5), (3.5, 3.5)][i]
                    let pt = CGPoint(x: (CGFloat(o.c) + offs.0) * cell + cell / 2,
                                     y: (CGFloat(o.r) + offs.1) * cell + cell / 2)
                    let isMov = side == .you && model.movable.contains(i)
                    spots.append(TokenSpot(id: "b\(gid)", side: side, index: i, point: pt, isMovable: isMov))
                } else if steps <= 55, let pos = model.boardCell(side: side, steps: steps) {
                    byCell[key(pos.r, pos.c), default: []].append(gid)
                } else if steps == 56 {
                    let cx: CGFloat = 7.5 * cell
                    let cy: CGFloat = 7.5 * cell
                    let offs: (CGFloat, CGFloat) = [(-0.45, -0.45), (0.45, -0.45), (-0.45, 0.45), (0.45, 0.45)][i]
                    let dx: CGFloat = side == .you ? -0.9 : (side == .cpu1 ? 0.9 : 0)
                    let dy: CGFloat = side == .cpu2 ? -0.9 : (side == .cpu3 ? 0.9 : 0)
                    let pt = CGPoint(x: cx + (offs.0 + dx) * cell * 0.55,
                                     y: cy + (offs.1 + dy) * cell * 0.55)
                    spots.append(TokenSpot(id: "f\(gid)", side: side, index: i, point: pt, isMovable: false))
                }
            }
        }

        let stackOffs: [(CGFloat, CGFloat)] = [
            (-0.24, -0.24), (0.24, -0.24), (-0.24, 0.24), (0.24, 0.24),
            (0, -0.3), (0, 0.3), (-0.3, 0), (0.3, 0),
        ]
        for (k, gids) in byCell {
            let parts = k.split(separator: "-")
            let r = Int(parts[0])!, c = Int(parts[1])!
            let center = CGPoint(x: (CGFloat(c) + 0.5) * cell, y: (CGFloat(r) + 0.5) * cell)
            for (n, gid) in gids.enumerated() {
                let side = sides[gid / 4]
                let idx = gid % 4
                let o = stackOffs[n % stackOffs.count]
                let pt = CGPoint(x: center.x + o.0 * cell, y: center.y + o.1 * cell)
                let isMov = side == .you && model.movable.contains(idx)
                spots.append(TokenSpot(id: "t\(gid)", side: side, index: idx, point: pt, isMovable: isMov))
            }
        }
        return spots
    }

    private func tokensOverlay(cell: CGFloat, size: CGFloat) -> some View {
        ZStack {
            ForEach(tokenSpots(cell: cell)) { spot in
                LudoToken(
                    color: color(for: spot.side),
                    radius: cell * 0.30,
                    isMovable: spot.isMovable,
                    onTap: { model.tapToken(spot.index) }
                )
                .position(spot.point)
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.7),
                   value: model.tokens)
        .allowsHitTesting(true)
    }

    // MARK: - Win

    private var winCard: some View {
        VStack(spacing: 12) {
            Text(model.winner?.isHuman == true
                 ? "YOU WIN! 🏆"
                 : "\((model.winner?.displayName ?? "CPU").uppercased()) WINS")
                .font(.title2.bold())
                .foregroundColor(model.winner == .you ? Theme.good : Theme.danger)
            Button(action: { model.newGame() }) {
                Text("Play Again")
                    .font(.title3.bold())
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(red: 0.18, green: 0.65, blue: 0.30))
                    .cornerRadius(12)
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.horizontal, 60)
        }
        .padding(.vertical, 16)
        .background(Theme.surface.opacity(0.6))
        .cornerRadius(16)
        .padding(.horizontal, 24)
        .transition(.scale.combined(with: .opacity))
    }
}

// A single Ludo token. Movable ones pulse so you know they're tappable.
struct LudoToken: View {
    let color: Color
    let radius: CGFloat
    let isMovable: Bool
    let onTap: () -> Void

    @State private var pulse = false

    var body: some View {
        ZStack {
            if isMovable {
                Circle()
                    .stroke(Color.white, lineWidth: 2.5)
                    .frame(width: radius * 2, height: radius * 2)
                    .scaleEffect(pulse ? 1.45 : 1.0)
                    .opacity(pulse ? 0 : 0.9)
            }
            Circle()
                .fill(
                    LinearGradient(colors: [color, color.opacity(0.65)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .frame(width: radius * 2, height: radius * 2)
                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                .shadow(color: color.opacity(0.7), radius: isMovable ? 8 : 3)
            Circle()
                .fill(Color.white.opacity(0.85))
                .frame(width: radius * 0.55, height: radius * 0.55)
                .offset(x: -radius * 0.25, y: -radius * 0.25)
        }
        .onTapGesture { if isMovable { onTap() } }
        .onAppear {
            // The pulse loop runs forever; the ring itself only renders while movable.
            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}
