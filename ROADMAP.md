# 5IN1 Roadmap

Five games, one native macOS app. This is the living plan — checked off as things ship.

## v3.1.1 — Animation & feel polish (in progress)
- [x] Fix 40GB memory leak (`.onReceive(Just(...))` → guarded `.onChange`)
- [x] Rename GameHub → 5IN1 (bundle, window title, plist, workflow, README)
- [x] Game-switch transition (fade + subtle scale) in the toolbar switcher
- [x] Win confetti in Ludo, Snakes & Ladders, Tic-Tac-Toe (Guessing already had it)
- [x] Animated result banner in Tic-Tac-Toe (spring on game over)
- [x] Harden `ConfettiView`: timer invalidated on disappear, no runaway timers
- [ ] Ship v3.1.1 build, verify signature + linked libs, user playtests all five games

## v3.2 — Gameplay depth
- [x] Snake: pause menu, game-over stats (length, time survived)
- [x] Guessing: streak tracking, daily-challenge style fixed seed mode
- [x] Ludo: 4-player mode (you + 3 CPU), faster CPU animation toggle
- [x] Snakes & Ladders: 2-player local pass-and-play
- [x] Tic-Tac-Toe: score streaks, "CPU thinks" indicator polish
- [x] Sound effects (subtle, mutable, off by default on first launch)
- [ ] Ship v3.2.0 build, verify signature + linked libs, user playtests all five games

## v3.2.1 — Hint parity with Android (in progress)
- [x] Guessing: cryptic hints (HintEngine Swift port — fun facts, digit wordplay, math riddles, range hints), 3 per round
- [ ] Ship v3.2.1 build, verify signature + linked libs, user playtests all five games

## v3.3 — Social & sharing
- [ ] Export/share score cards (PNG) for each game
- [ ] Local leaderboards across all five games on one screen

## v4.0 — Platform expansion
- [ ] iOS port (the `source/ios/` target already exists — needs wiring to the five games)
- [ ] Android scoping (portrait, basic — per earlier plan, Mac first)

## Non-goals
- No network multiplayer (keep it offline, zero dependencies)
- No accounts, no analytics, no ads
