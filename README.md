# RobloxProject

A 2.5D platform fighter (Smash-style) for Roblox starring AI brainrot meme characters.

## How we collaborate

**Studio (Team Create) for anything you build or see. GitHub for anything that's code.**

The place itself (maps, models, UI) lives on Roblox's servers and is edited together in Team Create. Code lives in this repo as text files and is synced into Studio by [Rojo](https://rojo.space/). Artists and level builders only need Studio; programmers use both.

### What goes where

| Part of the game | Where | Notes |
|---|---|---|
| Stages / maps (platforms, terrain, lighting, skybox) | Studio | Stage models go in `ReplicatedStorage.Assets.Stages` |
| Character models | Studio | `ReplicatedStorage.Assets.Characters.<Name>` |
| Animations | Studio (Animation Editor) | Publish, then put the asset ID in the character's data file |
| UI layout (damage %, stocks, character select) | Studio | Build in `StarterGui` |
| VFX and sounds | Studio | `ReplicatedStorage.Assets.VFX` / `ReplicatedStorage.Assets.Sounds` |
| Movement, 2D plane lock, jumping | GitHub | `src/` |
| Damage %, knockback, hitstun, hitboxes | GitHub | `src/` |
| Character stats and move data | GitHub | `src/shared/Characters/<Name>.luau` |
| Stocks, blast zones, match flow | GitHub | `src/server` |
| Camera, input, UI logic | GitHub | `src/client` |
| Concept art, Higgsfield outputs | GitHub (`ref images/`) | Small images only; large/video files go on a shared drive |

### Art pipeline (Higgsfield)

1. Generate concept art / reference sheets in Higgsfield and save the keepers to `ref images/`.
2. Turn them into 3D models (image-to-3D tool or Roblox mesh generation).
3. Import into Studio, rig, animate, and place in `ReplicatedStorage.Assets.Characters.<Name>`.
4. Hand the animation IDs to whoever owns that character's data file.

None of this touches git.

### Asset conventions (art ↔ code contract)

Code finds assets by name, so these must be followed:

- Character models: `ReplicatedStorage.Assets.Characters.<Name>`, with a `HumanoidRootPart` and hitbox attachments named `Hitbox_<Part>` (e.g. `Hitbox_RightHand`).
- **Never put anything inside `ReplicatedStorage.Shared`** — Rojo owns it and deletes anything not in `src/shared`. Studio-built content goes in `ReplicatedStorage.Assets`, which Rojo creates but leaves alone.
- Animation IDs live in code (the character's data file), not in the model.
- Stages are played on the plane **Z = 0**. Tag stage parts (Tag Editor, or Properties → Tags) so the movement code can collide with them: `StageSolid` for solid ground and walls, `StagePlatform` for pass-through platforms, and `StageSpawn` on one invisible, non-colliding part where fighters appear. Keep parts unrotated (or rotated in 90° steps). If a place has no `StageSolid` parts, the server builds a grey test stage.

## Layout

| Path | Syncs to (in Studio) | What goes here |
|---|---|---|
| `src/shared` | `ReplicatedStorage.Shared` | Modules used by both server and client (utilities, data) |
| `src/shared/Characters` | `ReplicatedStorage.Shared.Characters` | One data file per character: stats, animation IDs, moves. Copy `_Template.luau` to add one |
| `src/shared/Movement` | `ReplicatedStorage.Shared.Movement` | Pure 2D movement rules (run, jumps, short hop, double jump, fast-fall, landing lag, pass-through platforms) and their tuning in `Config.luau` |
| `src/shared/Stage` | `ReplicatedStorage.Shared.Stage` | `StageGeometry`: reads tagged stage parts into the rects movement collides with |
| `src/shared/Combat` | `ReplicatedStorage.Shared.Combat` | Pure fighting rules: `Fighter` (attacks with frame data, damage %, hitstun, hitstop, attack buffer), `Combat` (hit detection between fighters, blast-zone KOs), `Knockback` (Smash-style formula). Tuning in `Config.luau`. `TestMoveset` is a **placeholder** jab/tilt/smash/neutral-air until the first fighter design exists |
| `src/shared/Feel` | `ReplicatedStorage.Shared.Feel` | Pure game-feel math: hit tiers and the hitstop formula (`HitTiers`), KO slow-mo requests (`TimeScale`), effect envelopes, a small `Signal` |
| `src/server` | `ServerScriptService.Server` | Server logic: damage, knockback, hitboxes, stocks, match flow. `TestStage/` builds a test stage when the place has none |
| `src/client` | `StarterPlayer.StarterPlayerScripts.Client` | Input, camera, UI logic, effects. `Input/` turns keyboard, controller and touch into one intent per frame; `Fighter/` runs the local 60 Hz simulation (your fighter plus the training dummy) and plays the Feel effects on hits, KOs, jumps and landings |
| `src/client/Camera` | `…Client.Camera` | `FightCamera`: side-on camera that frames every fighter Smash-style, with shake and FOV punches. Framing math is in `Framing` |
| `src/client/Feel` | `…Client.Feel` | `Feel`: one entry point for hit/KO/movement juice (camera shake, haptics, layered impact audio, hit flash, sparks, flash limiter). Cosmetic only; tuning in `Config.luau` |
| `src/client/Training` | `…Client.Training` | Training dummy: an orange block you can hit and launch. Client-only; switch it off in `Config.luau` |
| `src/client/Hud` | `…Client.Hud` | Placeholder damage % labels over fighters, until the real HUD is built in Studio |
| `src/client/Settings` | `…Client.Settings` | Player settings store with presets (Default / Competitive): shake, flash, rumble, slow-mo toggles |
| `src/client/Dev` | `…Client.Dev` | `FeelHarness`: Studio-only preview of hit effects on two placeholder blocks (keys 1–9). Off by default; turn it on with a boolean Workspace attribute `FeelHarness` = true |
| `tests/` | — (not synced) | Unit tests (`*.spec.luau`, one folder per system), run with Lune outside Studio (see Setup) |
| `rokit.toml`, `stylua.toml`, `selene.toml`, `.luaurc` | — | Pinned tool versions (Rojo, StyLua, selene, Lune), formatter and linter settings, strict Luau |
| `.github/workflows/ci.yml` | — | CI on every push and pull request: format check, lint, unit tests, Rojo build |
| — | `ReplicatedStorage.Assets` (`Characters`, `Stages`, `VFX`, `Sounds`) | Created by Rojo, filled in Studio. Not stored in git |
| `ref images/` | — | Reference art for characters/stages (Higgsfield + Roblox generation) |
| `docs/GameScope.md` | — | **Start here.** The game's scope: vision, pillars, mechanics decisions, settled team decisions (marked DECIDED), build order |
| `docs/characters/` | — | One moveset design per character, written by the team. Copy `_MovesetTemplate.md`; Claude turns each into `src/shared/Characters/<Name>.luau` |
| `docs/research/` | — | Research behind the scope. `SUMMARY.md` has a one-paragraph abstract of each report: `successful-games.md` (what other fighters did well and badly), `game-feel.md` (hitstop, shake, sound, haptics, VFX), `input-and-netcode.md` (keyboard/controller/mobile controls, online architecture), `roblox-discovery.md` (how Roblox ranks games, launch checklist), `character-ip.md` (which characters are legally safe), `mechanics-design-prompt.md` (prior-art research on Smash mechanics plus a master prompt for writing the full mechanics spec) |

## Setup (programmers)

1. Install [Git](https://git-scm.com/) and [Rokit](https://github.com/rojo-rbx/rokit), the toolchain manager.
2. Clone this repo. From the repo folder, run `rokit install` to get the pinned versions of Rojo, StyLua, selene and Lune from `rokit.toml` (re-run it whenever that file changes), then install the Rojo Studio plugin with `rojo plugin install`.
3. From the repo folder run:

   ```bash
   rojo serve
   ```

4. Open a **local copy** of the place (open the Team Create place, then **File → Save to File** — `.rbxl` files are gitignored). Open the **Rojo** plugin tab and click **Connect**. Edits to files in `src/` now sync live into your copy for testing.

5. Press **Play** in Studio. You spawn on a grey test stage next to an orange training dummy.

   | | Keyboard | Controller | Touch |
   |---|---|---|---|
   | Move | WASD / arrow keys | Left stick / D-pad | Joystick (left half of the screen) |
   | Jump | Space | A or Y | Jump button |
   | Attack | J (jab; tilt while holding A/D; neutral air in the air) | X | Tap Attack |
   | Smash | L (aims with A/D) | Flick the right stick | Swipe sideways off Attack |

   Tap jump for a short hop, press down while falling to fast-fall, and press down on a thin platform to drop through it. Hit the dummy to raise its %; the side smash launches it off the stage from about 95%.

**Checks before you push** (CI runs the same ones on every pull request). From the repo folder:

```bash
lune run tests/run          # unit tests; add a name to run only matching specs: lune run tests/run Movement
stylua src tests            # format (CI runs stylua --check)
selene src tests            # lint
```

Game rules live in pure modules (no Instances), so their tests run in Lune without Studio. Add a test by creating `tests/<System>/<Module>.spec.luau` that returns `function(t)` (see `tests/Example.spec.luau`); the runner finds it automatically.

Artists and builders don't need any of this — just open the shared place in Studio.

## Workflow

- **Only one person runs Rojo into the shared Team Create place**, syncing from an up-to-date `main`. Everyone else tests code in their own local copy. Multiple people syncing into the shared place overwrite each other.
- Edit code in `src/`, never in Studio's script editor — Studio-side edits to synced scripts get overwritten.
- Avoid code conflicts: one folder per system (e.g. `src/shared/Knockback/`, with client- or server-only parts in `src/client/Knockback/` / `src/server/Knockback/`) with one owner each, and one data file per character.
- Code conventions (in `CLAUDE.md`): every module starts with `--!strict`, tabs for indentation, PascalCase module/folder names. Keep game rules and math in pure modules (no Instances or services) so they can be unit-tested, and put tunable numbers in a `Config` module per system. Timing is in 60 Hz frames and distances in studs, converted to seconds only for effects and UI.
- **Always work on your own branch — never commit directly to `main`.** Name it after the work (e.g. `knockback-system`, `char-skibidi`), then open a pull request into `main` when it's ready. **Every pull request must be approved by @2shotguns4me, who merges it — don't merge your own.** (GitHub can't enforce this on our plan, so it's on the honor system — but `.github/workflows/main-guard.yml` opens an issue alerting the owner whenever anyone else pushes to or merges into `main`.)

  ```bash
  git checkout main
  git pull
  git checkout -b knockback-system
  # ...make changes, commit...
  git push -u origin knockback-system
  # then open a pull request on GitHub
  ```

- Pull before you start, commit small, push often.
- Keep this README up to date when you change the project's layout, systems or setup. `CLAUDE.md` tells Claude Code to do this automatically.
