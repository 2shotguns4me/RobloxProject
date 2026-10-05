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

## Layout

| Path | Syncs to (in Studio) | What goes here |
|---|---|---|
| `src/shared` | `ReplicatedStorage.Shared` | Modules used by both server and client (utilities, data) |
| `src/shared/Characters` | `ReplicatedStorage.Shared.Characters` | One data file per character: stats, animation IDs, moves. Copy `_Template.luau` to add one |
| `src/server` | `ServerScriptService.Server` | Server logic: damage, knockback, hitboxes, stocks, match flow |
| `src/client` | `StarterPlayer.StarterPlayerScripts.Client` | Input, camera, UI logic, effects |
| — | `ReplicatedStorage.Assets` (`Characters`, `Stages`, `VFX`, `Sounds`) | Created by Rojo, filled in Studio. Not stored in git |
| `ref images/` | — | Reference art for characters/stages (Higgsfield + Roblox generation) |
| `docs/GameScope.md` | — | **Start here.** The game's scope: vision, pillars, mechanics decisions, open questions (marked DECIDE), build order |
| `docs/characters/` | — | One moveset design per character, written by the team. Copy `_MovesetTemplate.md`; Claude turns each into `src/shared/Characters/<Name>.luau` |
| `docs/research/` | — | Research behind the scope: `successful-games.md` (what other fighters did well and badly), `game-feel.md` (hitstop, shake, sound, haptics, VFX), `input-and-netcode.md` (keyboard/controller/mobile controls, online architecture), `roblox-discovery.md` (how Roblox ranks games, launch checklist), `character-ip.md` (which characters are legally safe), `mechanics-design-prompt.md` (prior-art research on Smash mechanics plus a master prompt for writing the full mechanics spec) |

## Setup (programmers)

1. Install [Git](https://git-scm.com/) and [Rojo](https://rojo.space/) (`winget install Rojo.Rojo`).
2. Install the Rojo Studio plugin: `rojo plugin install`.
3. Clone this repo, then from the repo folder run:

   ```bash
   rojo serve
   ```

4. Open a **local copy** of the place (open the Team Create place, then **File → Save to File** — `.rbxl` files are gitignored). Open the **Rojo** plugin tab and click **Connect**. Edits to files in `src/` now sync live into your copy for testing.

Artists and builders don't need any of this — just open the shared place in Studio.

## Workflow

- **Only one person runs Rojo into the shared Team Create place**, syncing from an up-to-date `main`. Everyone else tests code in their own local copy. Multiple people syncing into the shared place overwrite each other.
- Edit code in `src/`, never in Studio's script editor — Studio-side edits to synced scripts get overwritten.
- Avoid code conflicts: one module per system (e.g. `Knockback.luau`, `Hitbox.luau`) with one owner each, and one data file per character.
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
