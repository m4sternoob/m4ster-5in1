import SwiftUI

// Tic-Tac-Toe board — tap a square to place your X.

struct TicTacToeView: View {
    @StateObject private var model = TicTacToeModel()
    @EnvironmentObject private var coordinator: GameCoordinator

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                header

                Divider()
                    .background(Theme.divider)

                ScrollView {
                    VStack(spacing: 20) {
                        difficultyPicker

                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(0..<9) { i in
                                cell(i)
                            }
                        }
                        .frame(maxWidth: 400)

                        if model.cpuThinking {
                            HStack(spacing: 8) {
                                Text("CPU is thinking")
                                    .font(.headline)
                                    .foregroundColor(Theme.textPrimary)
                                ThinkingDots()
                            }
                            .transition(.opacity)
                        } else {
                            Text(model.message)
                                .font(model.gameOver ? .title2.bold() : .headline)
                                .foregroundColor(model.winner == .x ? Theme.good
                                    : model.winner == .o ? Theme.danger : Theme.textPrimary)
                                .animation(.spring(response: 0.35, dampingFraction: 0.6), value: model.gameOver)
                        }

                        HStack(spacing: 10) {
                            StatPill(icon: "person.fill", text: "You \(model.playerScore)")
                            StatPill(icon: "cpu", text: "CPU \(model.cpuScore)")
                            StatPill(icon: "equal", text: "Draws \(model.draws)")
                            if model.playerStreak > 0 {
                                StatPill(icon: "flame.fill", text: "Streak \(model.playerStreak)")
                            }
                        }

                        Button(action: { model.newGame() }) {
                            Text("New Game")
                                .font(.title3.bold())
                                .foregroundColor(.white)
                                .frame(maxWidth: 280)
                                .padding(.vertical, 12)
                                .background(Theme.accent)
                                .cornerRadius(12)
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                    .padding(24)
            }
        if model.winner == .x {
            ConfettiView()
        }
        }
        .onChange(of: coordinator.newGameID) { _, _ in
            model.resetForNewGameCommand()
        }
    }
}

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Tic-Tac-Toe")
                    .font(.title2.bold())
                    .foregroundColor(Theme.textPrimary)
                Text("You are X — three in a row wins")
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
    }

    private var difficultyPicker: some View {
        HStack {
            Text("CPU difficulty")
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)
            Picker("Difficulty", selection: $model.difficulty) {
                ForEach(TicTacToeModel.Difficulty.allCases) { d in
                    Text(d.rawValue).tag(d)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 200)
            .onChange(of: model.difficulty) { _, d in model.setDifficulty(d) }
        }
    }

    // MARK: - Board

    private func cell(_ i: Int) -> some View {
        let mark = model.board[i]
        let inWinLine = model.winningLine?.contains(i) == true
        return Button(action: { model.tap(i) }) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(inWinLine ? Color(red: 0.15, green: 0.45, blue: 0.22) : Theme.surface)
                Text(mark.rawValue)
                    .font(.system(size: 60, weight: .bold, design: .rounded))
                    .foregroundColor(mark == .x ? Color(red: 0.4, green: 0.65, blue: 1.0)
                                                : Color(red: 1.0, green: 0.6, blue: 0.25))
                    .scaleEffect(mark == .empty ? 0.3 : 1.0)
                    .opacity(mark == .empty ? 0 : 1)
            }
            .frame(height: 110)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.55), value: mark)
        .disabled(mark != .empty || model.gameOver || model.cpuThinking)
    }
}

// Three dots that pulse in sequence while the CPU picks its move.
struct ThinkingDots: View {
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(Theme.textSecondary)
                    .frame(width: 7, height: 7)
                    .opacity(pulse ? 1 : 0.25)
                    .animation(
                        .easeInOut(duration: 0.45)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.15),
                        value: pulse
                    )
            }
        }
        .onAppear { pulse = true }
    }
}
