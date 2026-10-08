import SwiftUI

// Root container: segmented switcher across the six games.
// (macOS idiom — a segmented toolbar control, not the iOS flip-card.)

enum ActiveGame: String, CaseIterable, Identifiable {
    case guessing
    case snake
    case ladders
    case ludo
    case tictactoe
    case twenty48

    var id: Self { self }

    var title: String {
        switch self {
        case .guessing: return "Guess"
        case .snake: return "Snake"
        case .ladders: return "Ladders"
        case .ludo: return "Ludo"
        case .tictactoe: return "TicTac"
        case .twenty48: return "2048"
        }
    }

    var icon: String {
        switch self {
        case .guessing: return "questionmark.circle"
        case .snake: return "gamecontroller"
        case .ladders: return "dice.fill"
        case .ludo: return "circle.grid.3x3.fill"
        case .tictactoe: return "grid"
        case .twenty48: return "square.grid.2x2.fill"
        }
    }
}

struct ContentView: View {
    @State private var activeGame: ActiveGame = .guessing
    @ObservedObject private var sound = SoundFX.shared

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            GridBackground().ignoresSafeArea()

            Group {
                switch activeGame {
                case .guessing:
                    GuessingGameView()
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                case .snake:
                    SnakeGameView()
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                case .ladders:
                    SnakesLaddersView()
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                case .ludo:
                    LudoView()
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                case .tictactoe:
                    TicTacToeView()
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                case .twenty48:
                    Twenty48View()
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: activeGame)
        }
        .preferredColorScheme(.dark)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Picker("Game", selection: $activeGame) {
                    ForEach(ActiveGame.allCases) { game in
                        Label(game.title, systemImage: game.icon).tag(game)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 540)
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    sound.isEnabled.toggle()
                } label: {
                    Image(systemName: sound.isEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                }
                .help(sound.isEnabled ? "Mute sound effects" : "Enable sound effects")
            }
        }
    }
}
