# 5IN1

<div align="center">

![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)
![SwiftUI](https://img.shields.io/badge/SwiftUI-macOS-blue.svg)
![Platform](https://img.shields.io/badge/Platform-macOS%2014%2B-lightgrey.svg)
![License](https://img.shields.io/badge/License-MIT-yellow.svg)
![Version](https://img.shields.io/badge/Version-v3.2.1-brightgreen.svg)

**Five games, one native macOS app — built with SwiftUI + SpriteKit, zero dependencies.**

[⬇️ Download](#-download) • [🎮 Games](#-games) • [🔨 Build from source](#-build-from-source)

</div>

---

## What's new in v3.2.1

The guessing game gets **cryptic hints** (💡, 3 per round): fun facts ("Say hi to my Valentine!"),
digit wordplay ("a zero stacked on top of another zero") and little math riddles — the same
HintEngine the Android build has, now on Mac.

## What's new in v3.2.0

Gameplay depth across all five games, plus subtle system-sound effects (off by
default — toggle the speaker in the toolbar):

- **Snake** — pause menu (`Space`/`P`, Resume/Restart) and game-over stats: length + time survived
- **Guessing** — persisted win streaks and a **daily challenge**: same number for everyone, seeded by the date, 1–100 with 10 attempts
- **Ludo** — 4-player mode (you + 3 CPU) with a **Fast CPU** animation toggle
- **Snakes & Ladders** — 2-player local pass-and-play
- **Tic-Tac-Toe** — win streaks and an animated "CPU is thinking" indicator

## What's new in v3.1.1

5IN1 grows from two games to **five**: Snakes & Ladders, Ludo (you vs the CPU),
and Tic-Tac-Toe join the Guessing Game and Snake. One window, one toolbar switcher,
shared dark theme, per-game stats saved on your Mac.

v3.0.0 was the full from-scratch native macOS rewrite — the old C++/SDL2 builds are
gone (they live on the `legacy/cpp-sdl2` branch for reference). No bundled dylibs:
pure Swift + SwiftUI, packaged as a normal Mac app.

## 🎮 Games

Switch anytime from the segmented control in the toolbar. `⌘N` starts a new game
in whichever game is active.

### 🎯 Guessing Game
- Difficulties: **Easy** (1–50), **Medium** (1–100), **Hard** (1–500), or **Custom** range
- **Attempt limits** (8 / 10 / 15; Custom is unlimited) — run out and the round is lost
- **Hot/cold proximity meter** (🧊 → 🚀) and a live "possible range" readout that narrows as you guess
- Quick picks (Min / 25% / 50% / 75% / Max), color-coded history (↑ too low, ↓ too high, ✓ correct)
- Best score per difficulty, lifetime games played + average attempts + win rate
- **Win streaks** (persisted) and a **daily challenge** — same date-seeded number for everyone, 1–100, 10 attempts
- Confetti on win, error toasts, `Return` submits
- **Cryptic hints** (💡, 3 per round) — fun facts, digit wordplay, math riddles

### 🐍 Snake
- 20×20 grid, gradient body, animated eyes, pulsing food
- **Speed selector** (Chill / Normal / Insane) and a **combo multiplier** for chained quick pickups
- **Wrap-walls mode** toggle, floating score popups, eat particles, death shake
- Speeds up as you eat; high score saved on your Mac
- **Arrow keys or WASD** to steer, `Space`/`P` to pause, clickable direction pad
- **Pause menu** (Resume/Restart) and game-over stats: final length + time survived

### 🪜 Snakes & Ladders
- Classic 100-square board with ladders, snakes, and exact-roll-to-win
- You (blue) vs the CPU (red) — animated dice, hop-by-hop token movement
- **2-player local pass-and-play** — hand the Mac to a friend
- Win/loss record saved on your Mac

### 🎲 Ludo
- Full 15×15 board: bases, safe ★ squares, home stretches, captures
- You (red) vs the CPU (yellow) — roll 6 to leave base, extra rolls on 6s and captures
- **4-player mode** (you + 3 CPUs) and a **Fast CPU** toggle for snappier turns
- Glowing tokens show your legal moves; CPU plays a real strategy (captures first, then racing home)

### ⭕ Tic-Tac-Toe
- You are X, CPU is O — Easy (casual) and Hard (unbeatable minimax) difficulties
- Winning-line highlight, score + draw tracking, **win streaks**, animated CPU-thinking dots

## ⬇️ Download

Once a v3.x build is published, grab the `.zip` from the
[**Releases**](https://github.com/m4sternoob/m4ster-5in1/releases) page,
unzip, and open `5IN1.app`. Requires macOS 14 (Sonoma) or later, Apple Silicon or Intel.

> ⚠️ Honest status: the builds on the [Releases](https://github.com/m4sternoob/m4ster-5in1/releases)
> page are still the old v1.0.0–v2.5.1 C++/SDL2 builds — broken, and superseded by this rewrite.
> Until a v3.x release is published, the quickest way to run it is to build from source below.

Since the app is ad-hoc signed (not notarized), macOS may refuse to open it on first launch.
**Right-click → Open** on `5IN1.app` once to get past Gatekeeper; after that it launches normally.

## 🔨 Build from source

You need Xcode 15+ (or just the Xcode command line tools):

```bash
swift build -c release
```

Or open `Package.swift` in Xcode and hit Run.

To make the distributable `.app` exactly like the release (bundle + icon + ad-hoc sign + zip),
trigger the **Build macOS app (Swift)** workflow under the repo's Actions tab.

## 📁 Project structure

```
Package.swift                  # Swift package, macOS 14+, zero dependencies
Sources/GuessingGame/
  GuessingGameApp.swift        # @main entry, window, ⌘N menu command
  ContentView.swift            # 5-game toolbar switcher
  Guessing/
    GuessModel.swift           # state machine + hot/cold proximity + stats
    HintEngine.swift           # cryptic hint generator (facts, wordplay, riddles)
    GuessingGameView.swift     # guessing game UI
  Snake/
    SnakeGameModel.swift       # snake rules (movement, food, wrap mode, speeds, combos)
    SnakeScene.swift           # SpriteKit 60fps renderer + juice (popups, particles)
    SnakeGameView.swift        # snake UI (keyboard + direction pad)
  SnakesLadders/
    SnakesLaddersModel.swift   # board rules, you vs CPU, dice flow
    SnakesLaddersView.swift    # 100-square SwiftUI board
  Ludo/
    LudoModel.swift            # 52-cell loop, captures, safe squares, CPU brain
    LudoView.swift             # 15x15 Canvas board + animated tokens
  TicTacToe/
    TicTacToeModel.swift        # rules + minimax AI
    TicTacToeView.swift        # board UI
  Components/
    Theme.swift                # dark theme, grid bg, confetti, toasts
    DiceView.swift             # animated die shared by the board games
packaging/
  Info.plist                   # bundle metadata used by CI
  generate_icon.py             # draws AppIcon-1024.png at build time (no binary in git)
source/ios/                    # iOS/SwiftUI version (separate target)
```

## 📜 Version history

- **v3.2.1** — cryptic hints in the guessing game (💡 3 per round: fun facts, digit wordplay, math riddles)
- **v3.2.0** — gameplay depth: snake pause + run stats, guessing streaks + daily challenge, 4-player Ludo, 2-player Snakes & Ladders, TTT streaks + thinking indicator, subtle sound FX (off by default)
- **v3.1.1** — five-game 5IN1: + Snakes & Ladders, Ludo, Tic-Tac-Toe; guessing hot/cold meter; snake wrap mode + juice
- **v3.0.0** — from-scratch native macOS rewrite (Swift/SwiftUI/SpriteKit)
- **v2.5.x** — C++/SDL2 builds (broken, superseded)
- **v1.0.0 / v2.0.0** — early C++/SDL2 builds (ran on dev machine only)

## 📄 License

MIT — see [LICENSE](LICENSE).

## 💬 Feedback

Found a bug or want a game added? Open an issue, or reach me at
[masternoob102030@gmail.com](mailto:masternoob102030@gmail.com).
