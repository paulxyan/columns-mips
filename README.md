# Columns (MIPS Assembly) — CSC258 Hardware Project

A retro “Columns” falling-block puzzle game implemented in **MIPS assembly**, designed to run in a MIPS simulator with **memory-mapped I/O** (bitmap display + keyboard).

This project demonstrates low-level systems skills: graphics via a memory-mapped framebuffer, keyboard polling, a game loop, collision detection, and match detection (horizontal / vertical / diagonal).

## Demo at a glance
- **Language:** MIPS assembly
- **Runtime:** Saturn or MARS (MIPS simulators)
- **I/O:** Memory-mapped bitmap display + keyboard input (polling)
- **Completed milestones:** 1–3 (static scene, controls, collision + matching)

---

## How to run

You can run the game using **Saturn** (recommended) or **MARS**.

### Option A — Saturn (recommended)
1. Open Saturn and load: `src/Columns.asm`
2. Open the Bitmap/Terminal window (Saturn uses a terminal pane for bitmap settings).
3. Configure the bitmap display:
   - **Base address:** `0x10008000`  
   - Set a display size that matches the project (our game renders within a 256x256 pixel bitmap with unit size 8).
4. Run / Assemble (Play).
5. Click the bitmap window so it captures your keystrokes.

Notes:
- Saturn sends keystrokes to the program while the bitmap window is focused.
- The project spec explains Saturn setup steps and base address details.

### Option B — MARS
1. Open MARS and load: `src/Columns.asm`
2. Tools → **Bitmap Display**
   - Set **Base address** to `0x10008000`
   - Click **Connect to MIPS** (leave the window open)
3. Tools → **Keyboard and Display MMIO Simulator**
   - Click **Connect to MIPS** (leave the window open)
4. Run → Assemble, then Run → Go
5. Type controls into the Keyboard MMIO window.

---

## Controls
Uses classic WASD controls:
- **A**: move left
- **D**: move right
- **W**: shuffle/cycle the order of the 3-gem column
- **S**: accelerate downward (drop faster)

(These are the core controls required by the project spec.)

---

## Gameplay summary
You control a vertical column of three colored gems. Move it left/right, shuffle the gem order, and drop it faster. When the column lands (bottom or on another piece), it locks in place and a new column spawns. Matches of 3+ gems (horizontal/vertical/diagonal) clear.

Game ends when stacked pieces reach the top.

---

## What an employer should look at (fast walkthrough)

### 1) Project overview (2 minutes)
- Read the first page of `docs/project_report.pdf` for:
  - what milestones were completed
  - board + bitmap dimensions
  - gameplay summary and controls

### 2) Run the game (5 minutes)
- Follow the “How to run” steps above and confirm:
  - bitmap display shows the game board
  - WASD inputs move/shuffle/drop the current column
  - landing/collision behaves correctly

### 3) Source code tour (5–10 minutes)
Open `src/Columns.asm` and look for:
- **Main game loop**: poll input → update state → draw → sleep → repeat
- **Memory-mapped I/O**:
  - keyboard polling (MMIO)
  - bitmap framebuffer writes (MMIO)
- **Core logic**:
  - spawning the next 3-gem column (randomized colors)
  - collision checks (walls, floor, existing gems)
  - match detection (horizontal / vertical / diagonal)
  - clearing matched gems + applying gravity

### 4) Design artifacts (optional)
See diagrams in `docs/project_report.pdf` for the matching algorithm and gravity logic.

---

## Repo contents
- `src/Columns.asm` — MIPS assembly source
- `docs/project_report.pdf` — submitted report with design notes and diagrams
- `docs/assignment_spec.pdf` — original assignment spec (constraints + expected controls)

---

## Credits
Created for CSC258 Assembly Project: Columns.
Authors: Paul Yan, Dylan Ma
