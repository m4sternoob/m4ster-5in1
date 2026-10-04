import SwiftUI

// Number guessing game — macOS layout.
// Range setup -> guessing (quick picks, hot/cold meter, history) -> win celebration.

struct GuessingGameView: View {
    @StateObject private var model = GuessModel()
    @EnvironmentObject private var coordinator: GameCoordinator
    @FocusState private var guessFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()
                .background(Theme.divider)

            ScrollView {
                VStack(spacing: 20) {
                    switch model.phase {
                    case .setup:
                        setupCard
                    case .playing:
                        playingCard
                    case .won:
                        wonCard
                    case .lost:
                        lostCard
                    }
                }
                .padding(24)
            }

            if model.errorMessage != nil {
                ErrorToast(message: model.errorMessage ?? "") {
                    model.dismissError()
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: model.errorMessage)
        .overlay {
            if model.phase == .won {
                ConfettiView()
                    .allowsHitTesting(false)
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
                Text("Guessing Game")
                    .font(.title2.bold())
                    .foregroundColor(Theme.textPrimary)
                Text("Guess the secret number")
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
            }
            Spacer()
            if let best = model.best {
                Label("Best: \(best)", systemImage: "trophy.fill")
                    .font(.subheadline.bold())
                    .foregroundColor(Theme.warnLow)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Theme.surface2)
                    .cornerRadius(8)
            } else {
                Label("Best: —", systemImage: "trophy")
                    .font(.subheadline)
                    .foregroundColor(Theme.textMuted)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Theme.surface2)
                    .cornerRadius(8)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
    }

    // MARK: - Setup

    private var setupCard: some View {
        VStack(spacing: 18) {
            Text("Choose difficulty")
                .font(.headline)
                .foregroundColor(Theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Picker("Difficulty", selection: $model.difficulty) {
                ForEach(GuessModel.Difficulty.allCases) { d in
                    Text(d.rawValue).tag(d)
                }
            }
            .pickerStyle(.segmented)
            .disabled(model.dailyMode)
            .opacity(model.dailyMode ? 0.5 : 1.0)
            .onChange(of: model.difficulty) { _, new in
                model.selectDifficulty(new)
            }

            Toggle("Daily challenge", isOn: $model.dailyMode)
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)
                .toggleStyle(.switch)

            if model.dailyMode {
                Text("📅 \(model.dailyDateLabel) — same number for everyone today • 1–100 • 10 attempts")
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Min")
                        .font(.caption)
                        .foregroundColor(Theme.textMuted)
                    TextField("1", text: $model.minText)
                        .font(.title3)
                        .foregroundColor(Theme.textPrimary)
                        .padding(12)
                        .background(Theme.surface)
                        .cornerRadius(10)
                        .disabled(model.difficulty != .custom)
                        .opacity(model.difficulty != .custom ? 0.5 : 1.0)
                        .onChange(of: model.minText) { _, new in
                            let filtered = new.filter(\.isNumber)
                            if filtered != new { model.minText = filtered }
                        }
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Max")
                        .font(.caption)
                        .foregroundColor(Theme.textMuted)
                    TextField("100", text: $model.maxText)
                        .font(.title3)
                        .foregroundColor(Theme.textPrimary)
                        .padding(12)
                        .background(Theme.surface)
                        .cornerRadius(10)
                        .disabled(model.difficulty != .custom)
                        .opacity(model.difficulty != .custom ? 0.5 : 1.0)
                        .onChange(of: model.maxText) { _, new in
                            let filtered = new.filter(\.isNumber)
                            if filtered != new { model.maxText = filtered }
                        }
                }
            }

            if model.difficulty != .custom,
               let r = model.difficulty.range,
               let limit = model.difficulty.attemptLimit,
               !model.dailyMode {
                Text("Range \(r.0)–\(r.1) • \(limit) attempts")
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
            } else if model.dailyMode {
                Text("Daily: 1–100 • 10 attempts")
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
            } else if model.difficulty == .custom {
                Text("Unlimited attempts")
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
            }

            Button(action: { model.startGame() }) {
                Text("Start Game")
                    .font(.title3.bold())
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Theme.accent)
                    .cornerRadius(14)
            }
            .buttonStyle(ScaleButtonStyle())

            if model.gamesPlayed > 0 {
                HStack(spacing: 10) {
                    StatPill(icon: "gamecontroller.fill",
                             text: "\(model.gamesPlayed) played")
                    StatPill(icon: "flame.fill",
                             text: "\(model.streak) streak")
                    StatPill(icon: "chart.bar.fill",
                             text: String(format: "%.1f avg", model.avgAttempts))
                    StatPill(icon: "percent",
                             text: String(format: "%.0f%% wins", model.winRate * 100))
                }
            }

            Text("Tip: press Return to submit a guess.")
                .font(.caption)
                .foregroundColor(Theme.textMuted)
        }
        .padding(20)
        .background(Theme.surface.opacity(0.6))
        .cornerRadius(16)
    }

    // MARK: - Playing

    private var playingCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Range: \(model.rangeLabel)")
                Spacer()
                if let left = model.attemptsLeft {
                    Text("Attempts left: \(left)")
                        .bold()
                        .foregroundColor(left <= 2 ? Theme.danger : Theme.textSecondary)
                } else {
                    Text("Attempts: \(model.attempts.count)")
                }
            }
            .font(.subheadline)
            .foregroundColor(Theme.textSecondary)

            Divider().background(Theme.divider)

            Text(model.message)
                .font(.body)
                .foregroundColor(messageColor)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .fixedSize(horizontal: false, vertical: true)
                .animation(.easeInOut(duration: 0.2), value: model.message)

            if let p = model.proximity {
                Text("\(p.emoji) \(p.label)")
                    .font(.headline)
                    .foregroundColor(proximityColor(p))
                    .transition(.scale.combined(with: .opacity))
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: model.attempts.count)
            }

            Text("Possible: \(model.possibleLo)–\(model.possibleHi)")
                .font(.subheadline)
                .foregroundColor(Theme.textMuted)

            Divider().background(Theme.divider)

            VStack(alignment: .leading, spacing: 10) {
                Text("Your Guess")
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)

                HStack(spacing: 10) {
                    TextField("Enter number", text: $model.guessText)
                        .font(.title2)
                        .foregroundColor(Theme.textPrimary)
                        .padding(14)
                        .background(Theme.surface)
                        .cornerRadius(12)
                        .focused($guessFieldFocused)
                        .onChange(of: model.guessText) { _, new in
                            let filtered = new.filter(\.isNumber)
                            if filtered != new { model.guessText = filtered }
                        }
                        .onSubmit { model.submitGuess() }

                    Button(action: { model.submitGuess() }) {
                        Text("Guess")
                            .font(.title3.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 22)
                            .padding(.vertical, 12)
                            .background(Theme.accent)
                            .cornerRadius(12)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .disabled(model.guessText.isEmpty)
                }
            }
            .onAppear { guessFieldFocused = true }

            Button(action: { model.askHint() }) {
                Label("Hint (\(model.hintsLeft) left)", systemImage: "lightbulb.fill")
                    .font(.subheadline.bold())
                    .foregroundColor(model.hintsLeft > 0 ? Theme.warnLow : Theme.textMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Theme.surface2)
                    .cornerRadius(10)
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(model.hintsLeft == 0)

            if let hint = model.shownHints.last {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(Theme.warnLow)
                    Text(hint)
                        .font(.subheadline)
                        .foregroundColor(Theme.textPrimary)
                    Spacer()
                }
                .padding(12)
                .background(Theme.warnLow.opacity(0.12))
                .cornerRadius(10)
                .transition(.scale.combined(with: .opacity))
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Quick Picks")
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)

                HStack(spacing: 8) {
                    ForEach(model.quickPicks, id: \.0) { label, value in
                        Button(action: { model.quickPick(value) }) {
                            Text(label)
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Theme.surface2)
                                .cornerRadius(10)
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
            }

            if !model.attempts.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("History (\(model.attempts.count))")
                        .font(.headline)
                        .foregroundColor(Theme.textSecondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(model.attempts.reversed()) { attempt in
                                HistoryChip(attempt: attempt)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: model.shownHints.count)
        .padding(20)
        .background(Theme.surface.opacity(0.6))
        .cornerRadius(16)
    }

    // MARK: - Won

    private var wonCard: some View {
        VStack(spacing: 18) {
            Text("YOU WON!")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundColor(Theme.good)

            Text("The number was \(model.attempts.last?.value ?? 0)")
                .font(.title3)
                .foregroundColor(Theme.textSecondary)

            Text("Guessed in \(model.attempts.count) attempt\(model.attempts.count == 1 ? "" : "s")!")
                .font(.title3)
                .foregroundColor(Theme.textSecondary)

            if model.isNewBest {
                Label("New best score!", systemImage: "trophy.fill")
                    .font(.headline)
                    .foregroundColor(Theme.warnLow)
            }

            if model.streak > 1 {
                Label("\(model.streak)-game win streak!", systemImage: "flame.fill")
                    .font(.headline)
                    .foregroundColor(Color(red: 1.0, green: 0.55, blue: 0.25))
            }

            Divider().background(Theme.divider)

            Button(action: { model.playAgain() }) {
                Text("Play Again")
                    .font(.title3.bold())
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(red: 0.18, green: 0.65, blue: 0.30))
                    .cornerRadius(14)
            }
            .buttonStyle(ScaleButtonStyle())

            Button(action: { model.backToSetup() }) {
                Text("Change Difficulty")
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Theme.surface2)
                    .cornerRadius(12)
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(20)
        .background(Theme.surface.opacity(0.6))
        .cornerRadius(16)
    }

    // MARK: - Lost

    private var lostCard: some View {
        VStack(spacing: 18) {
            Text("OUT OF ATTEMPTS")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundColor(Theme.danger)

            Text(model.message)
                .font(.title3)
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)

            Text("You used \(model.attempts.count) attempts.")
                .font(.subheadline)
                .foregroundColor(Theme.textMuted)

            Divider().background(Theme.divider)

            Button(action: { model.playAgain() }) {
                Text("Try Again")
                    .font(.title3.bold())
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Theme.accent)
                    .cornerRadius(14)
            }
            .buttonStyle(ScaleButtonStyle())

            Button(action: { model.backToSetup() }) {
                Text("Change Difficulty")
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Theme.surface2)
                    .cornerRadius(12)
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(20)
        .background(Theme.surface.opacity(0.6))
        .cornerRadius(16)
    }

    // MARK: - Helpers

    private var messageColor: Color {
        switch model.tone {
        case .neutral: return Theme.textPrimary
        case .low: return Theme.warnLow
        case .high: return Theme.warnHigh
        case .error: return Theme.danger
        case .win: return Theme.good
        }
    }

    private func proximityColor(_ p: GuessModel.Proximity) -> Color {
        switch p {
        case .freezing: return Color(red: 0.45, green: 0.65, blue: 1.0)
        case .cold: return Color(red: 0.45, green: 0.85, blue: 1.0)
        case .warm: return Color(red: 1.0, green: 0.75, blue: 0.35)
        case .hot: return Color(red: 1.0, green: 0.5, blue: 0.25)
        case .burning: return Color(red: 1.0, green: 0.3, blue: 0.3)
        }
    }
}

// One past guess, color-coded by hint.
struct HistoryChip: View {
    let attempt: GuessModel.Attempt

    private var color: Color {
        switch attempt.hint {
        case .low: return Theme.warnLow
        case .high: return Theme.warnHigh
        case .correct: return Theme.good
        }
    }

    private var indicator: String {
        switch attempt.hint {
        case .low: return " ↑"
        case .high: return " ↓"
        case .correct: return " ✓"
        }
    }

    var body: some View {
        VStack(spacing: 3) {
            Text("#\(attempt.number)")
                .font(.caption2)
                .foregroundColor(Theme.textMuted)
            Text("\(attempt.value)\(indicator)")
                .font(.title3.bold())
                .foregroundColor(color)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Theme.surface)
        .cornerRadius(10)
    }
}
