import SwiftUI

// 2048 board — arrow keys or WASD to slide, on-screen pad for mouse
// players. Hint flashes the roomiest move as an arrow over the board.

struct Twenty48View: View {
    @StateObject private var model = Twenty48Model()
    @EnvironmentObject private var coordinator: GameCoordinator
    @FocusState private var boardFocused: Bool

    private let tileSize: CGFloat = 84
    private let tileSpacing: CGFloat = 10

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()
                .background(Theme.divider)

            ScrollView {
                VStack(spacing: 18) {
                    board
                        .focusable()
                        .focused($boardFocused)
                        .onKeyPress(.leftArrow) { model.move(.left); return .handled }
                        .onKeyPress(.rightArrow) { model.move(.right); return .handled }
                        .onKeyPress(.upArrow) { model.move(.up); return .handled }
                        .onKeyPress(.downArrow) { model.move(.down); return .handled }
                        .onKeyPress("a") { model.move(.left); return .handled }
                        .onKeyPress("d") { model.move(.right); return .handled }
                        .onKeyPress("w") { model.move(.up); return .handled }
                        .onKeyPress("s") { model.move(.down); return .handled }

                    controlsHint

                    directionPad

                    HStack(spacing: 12) {
                        Button(action: {
                            model.showHint()
                            boardFocused = true
                        }) {
                            Label("Hint", systemImage: "lightbulb.fill")
                                .font(.headline.bold())
                                .foregroundColor(model.isGameOver ? Theme.textMuted : Theme.warnLow)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Theme.surface2)
                                .cornerRadius(12)
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .disabled(model.isGameOver)

                        Button(action: {
                            model.newGame()
                            boardFocused = true
                        }) {
                            Text("New Game")
                                .font(.headline.bold())
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Theme.accent)
                                .cornerRadius(12)
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                    .frame(maxWidth: 400)
                }
                .padding(24)
            }
        }
        .onAppear { boardFocused = true }
        .onChange(of: coordinator.newGameID) { _, _ in
            model.resetForNewGameCommand()
            boardFocused = true
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("2048")
                    .font(.title2.bold())
                    .foregroundColor(Theme.textPrimary)
                Text("Slide and merge tiles — chase the 2048 tile.")
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("Score: \(model.score)")
                    .font(.title3.bold())
                    .foregroundColor(Theme.textPrimary)
                if model.best > 0 {
                    Label("Best: \(model.best)", systemImage: "trophy.fill")
                        .font(.subheadline.bold())
                        .foregroundColor(Theme.warnLow)
                } else {
                    Label("Best: —", systemImage: "trophy")
                        .font(.subheadline)
                        .foregroundColor(Theme.textMuted)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
    }

    // MARK: - Board

    private var board: some View {
        ZStack {
            VStack(spacing: tileSpacing) {
                ForEach(0..<twenty48GridSize, id: \.self) { r in
                    HStack(spacing: tileSpacing) {
                        ForEach(0..<twenty48GridSize, id: \.self) { c in
                            Twenty48Tile(value: model.board[r * twenty48GridSize + c],
                                         size: tileSize)
                        }
                    }
                }
            }
            .padding(12)
            .background(Theme.surface)
            .cornerRadius(16)

            if let dir = model.hintDirection {
                Image(systemName: chevronName(for: dir))
                    .font(.system(size: 110, weight: .bold))
                    .foregroundColor(Theme.good.opacity(0.85))
                    .transition(.opacity)
            }

            if model.isGameOver {
                ZStack {
                    Color.black.opacity(0.6)
                    VStack(spacing: 12) {
                        Text("No moves left")
                            .font(.title2.bold())
                            .foregroundColor(Theme.textPrimary)
                        Text("Score: \(model.score)")
                            .font(.title3)
                            .foregroundColor(Theme.textSecondary)
                        Button(action: {
                            model.newGame()
                            boardFocused = true
                        }) {
                            Text("New Game")
                                .font(.headline.bold())
                                .foregroundColor(.white)
                                .padding(.horizontal, 28)
                                .padding(.vertical, 12)
                                .background(Theme.accent)
                                .cornerRadius(12)
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                    .padding(28)
                    .background(Theme.surface)
                    .cornerRadius(16)
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: model.hintDirection)
        .animation(.easeInOut(duration: 0.25), value: model.isGameOver)
    }

    private func chevronName(for dir: Twenty48Direction) -> String {
        switch dir {
        case .up: return "chevron.up"
        case .down: return "chevron.down"
        case .left: return "chevron.left"
        case .right: return "chevron.right"
        }
    }

    // MARK: - Controls

    private var controlsHint: some View {
        Text("Arrow keys or WASD to slide • Hint flashes the roomiest move")
            .font(.subheadline)
            .foregroundColor(Theme.textMuted)
    }

    private var directionPad: some View {
        VStack(spacing: 6) {
            padButton(.up, icon: "chevron.up")
            HStack(spacing: 6) {
                padButton(.left, icon: "chevron.left")
                padButton(.down, icon: "chevron.down")
                padButton(.right, icon: "chevron.right")
            }
        }
        .opacity(model.isGameOver ? 0.4 : 1.0)
        .disabled(model.isGameOver)
    }

    private func padButton(_ direction: Twenty48Direction, icon: String) -> some View {
        Button(action: {
            model.move(direction)
            boardFocused = true
        }) {
            Image(systemName: icon)
                .font(.title3.bold())
                .foregroundColor(.white)
                .frame(width: 44, height: 36)
                .background(Theme.surface2)
                .cornerRadius(8)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// One tile: empty cells stay on the board color, numbered tiles climb
// a warm ramp toward green at 2048. Big numbers shrink to fit.
struct Twenty48Tile: View {
    let value: Int
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(tileColor(value))
            if value != 0 {
                Text("\(value)")
                    .font(.system(size: fontSize, weight: .bold, design: .rounded))
                    .foregroundColor(value < 8 ? darkText : lightText)
            }
        }
        .frame(width: size, height: size)
        .animation(.easeInOut(duration: 0.12), value: value)
    }

    private var fontSize: CGFloat {
        switch value {
        case ..<100: return 28
        case ..<1000: return 24
        default: return 20
        }
    }

    private var darkText: Color { Color(red: 0.15, green: 0.18, blue: 0.24) }
    private var lightText: Color { Color(red: 251 / 255, green: 247 / 255, blue: 239 / 255) }

    private func tileColor(_ value: Int) -> Color {
        switch value {
        case 0: return Theme.surface2
        case 2: return Color(red: 51 / 255, green: 65 / 255, blue: 94 / 255)
        case 4: return Color(red: 61 / 255, green: 78 / 255, blue: 112 / 255)
        case 8: return Color(red: 224 / 255, green: 138 / 255, blue: 60 / 255)
        case 16: return Color(red: 224 / 255, green: 123 / 255, blue: 46 / 255)
        case 32: return Color(red: 222 / 255, green: 106 / 255, blue: 90 / 255)
        case 64: return Color(red: 219 / 255, green: 79 / 255, blue: 61 / 255)
        case 128: return Color(red: 242 / 255, green: 193 / 255, blue: 78 / 255)
        case 256: return Color(red: 240 / 255, green: 180 / 255, blue: 41 / 255)
        case 512: return Color(red: 238 / 255, green: 159 / 255, blue: 26 / 255)
        case 1024: return Color(red: 236 / 255, green: 143 / 255, blue: 10 / 255)
        case 2048: return Color(red: 74 / 255, green: 222 / 255, blue: 128 / 255)
        default: return Color(red: 96 / 255, green: 165 / 255, blue: 250 / 255)
        }
    }
}
