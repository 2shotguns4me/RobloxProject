# Testing workflow

Two kinds of testing, and every change gets both:

1. **Automated checks** — unit tests, format, lint and a build. Run anywhere, including CI and cloud Claude sessions.
2. **Play-test in Studio** — the only way to see the game and judge how it feels. Needs Roblox Studio on your own PC.

## 1. Automated checks

Run from the repo folder before pushing. CI (`.github/workflows/ci.yml`) runs the same four on every push and pull request, and a pull request isn't ready to merge until CI is green.

```bash
lune run tests/run          # unit tests (add a name to run only matching specs: lune run tests/run Combat)
stylua src tests            # format (CI runs stylua --check)
selene src tests            # lint
rojo build -o build.rbxl    # the project builds
```

The tools come from `rokit.toml` (`rokit install`). Game rules live in pure modules, so their tests run without Studio. Add a test as `tests/<System>/<Module>.spec.luau` returning `function(t)`; the runner finds it automatically (see `tests/Example.spec.luau`).

## 2. Play-test in Studio

### Every time

On your PC, in **VS Code opened on the local folder** (`File → Open Folder…` → your `RobloxProject` folder; not a GitHub Codespace):

1. **Get the latest code.** Terminal (`⋯ → Terminal → New Terminal`):

   ```powershell
   git pull
   rojo serve
   ```

   Leave `rojo serve` running.
2. **Open a local copy of the place** in Studio: a `.rbxl` you saved with **File → Save to File** (gitignored), or a blank Baseplate. Never sync into the shared Team Create place unless you're the one person doing that (see the README's Workflow).
3. **Connect Rojo while stopped (Edit mode):** **Plugins → Rojo → Connect**. It shows `RobloxProject · localhost:34872`.
4. **Press Play** (F5). The server builds the grey test stage and you spawn next to the orange training dummy.
5. **Check the list below**, and keep **View → Output** open for red errors.
6. **Finish:** **Stop** (Shift+F5) → **Disconnect** in the Rojo panel → **Ctrl+C** in the `rojo serve` terminal. Don't save `test.rbxl`/your local copy just to keep scripts; Rojo refills them on the next connect.

Shortcut without the plugin: `rojo build -o test.rbxl`, then open `test.rbxl` in Studio. It has every script but none of the Team Create builds, and edits don't sync live.

### What to check

Controls are in the README's Setup section.

- [ ] **No red errors** in Output from our scripts (`Client`, `Server`, `Shared`).
- [ ] **Movement:** run, walk (partial stick), full hop vs short hop (tap), double jump, fast-fall (press down after the apex), land on and drop through thin platforms, walls and ceilings stop you.
- [ ] **Combat:** jab (J), tilt (A/D + J), smash (L), neutral air (J in the air). Each hit raises the dummy's % once, freezes both of you briefly (hitstop), shakes and sparks. A smash at ~95% from mid-stage KOs; the dummy respawns.
- [ ] **Camera** keeps you and the dummy in frame.
- [ ] **Falling off** the stage KOs you and respawns you.
- [ ] **Chat:** typing (W, A, S, D, J, L) doesn't move or attack.
- [ ] **Reset** (Esc → Reset Character): you can still move and attack.
- [ ] **Controller** if you have one: stick/D-pad, A or Y jump, X attack, right-stick flick smash.
- [ ] **Touch:** **Test → Device** → pick a phone, then Play: joystick on the left half, Jump and Attack buttons, swipe off Attack to smash.

The Feel harness previews hit effects on two placeholder blocks: add a boolean Workspace attribute `FeelHarness` = true, Play, then keys 1–9.

### Common problems

| Symptom | Fix |
|---|---|
| Rojo: *"Http requests can only be executed by game server"* | You clicked Connect while playing. Stop, connect in Edit mode, then Play. |
| `git` or `rojo` *"not recognized"* in VS Code's terminal | VS Code started before they were installed. Quit VS Code completely and reopen it. |
| Terminal prompt starts with `@<name> ➜ /workspaces/…` | That's a GitHub Codespace (a cloud machine). Close it (green button bottom-left → Close Remote Connection) and open the local folder. |
| `git pull` reports a merge conflict | Run `git merge --abort` and ask Claude; don't serve conflicted files into Studio. |
| Sky only, no stage, after pressing Play | Check Output for errors and paste them to Claude. |

## 3. Playtesting with local Claude (Roblox Studio connection)

Cloud Claude sessions can't reach Studio. **Claude Code running on your PC** (the VS Code extension or `claude` in a terminal) can, through the Roblox Studio MCP server. One-time setup, from the repo folder:

```powershell
claude mcp add --transport stdio Roblox_Studio -- "cmd.exe" "/c" "cd /d %LOCALAPPDATA%\Roblox && .\mcp.bat"
```

Then, with Studio open and Rojo connected, start Claude in the repo folder, check `/mcp` shows **Roblox_Studio** connected, and paste:

```
Roblox Studio is open with this repo synced by Rojo. Play-test it:
1. Start a Play test.
2. Check the Output window for errors or warnings from our scripts.
3. Go through the "What to check" list in docs/Testing.md as far as you can drive input.
4. Stop the test and report: errors (with script and line), what worked, what didn't.
Don't change any code; just report.
```

It can run the game and read errors but can't judge feel. Keep it to reporting so code changes stay in one place; bring the report to whoever is making the change.

## 4. Reporting problems

Give Claude (or a teammate) something it can act on:

- **Errors:** copy the red text from Output, including the script name and line.
- **Behaviour:** what you did, what happened, what you expected — e.g. "pressed L facing left, the smash went right".
- **Feel:** plain words map straight to tuning numbers, no video needed:

  | You say | Where it's tuned |
  |---|---|
  | Running too fast/slow, jumps too high/floaty, falls too slow | `src/shared/Movement/Config.luau` |
  | Hits send too far/not far enough, KO too early/late, too much stun | `src/shared/Combat/Config.luau` |
  | An attack is too slow/fast or too strong/weak, hitbox too big/small | `src/shared/Combat/TestMoveset.luau` (later each fighter's data file) |
  | Hit freeze, shake, sparks, sound, rumble | `src/shared/Feel/HitTiers.luau`, `src/client/Feel/Config.luau` |
  | Camera too close/far, too slow to follow | `src/client/Camera/Config.luau` |
  | Touch buttons too small, in the wrong place | `src/client/Input/Config.luau` |

- **Screenshots** help with anything visual. **Screen recordings:** keep them short (5–15 s, one problem each) and say the timestamp; Claude can only look at extracted still frames, so describe anything about timing or feel in words too.
