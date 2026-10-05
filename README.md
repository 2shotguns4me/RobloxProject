# RobloxProject

A 2.5D platform fighter (Smash-style) for Roblox starring AI brainrot meme characters.

## Layout

| Path | Syncs to (in Studio) | What goes here |
|---|---|---|
| `src/shared` | `ReplicatedStorage.Shared` | Modules used by both server and client (character stats, move data, utilities) |
| `src/server` | `ServerScriptService.Server` | Server logic: damage, knockback, hitboxes, stocks, match flow |
| `src/client` | `StarterPlayer.StarterPlayerScripts.Client` | Input, camera, UI, effects |
| `ref images/` | — | Reference art for characters/stages (used for Higgsfield + Roblox generation) |

Models, stages and other visual assets are built directly in Studio (not synced by Rojo).

## Setup (each collaborator)

1. Install [Git](https://git-scm.com/) and [Rojo](https://rojo.space/) (`winget install Rojo.Rojo`).
2. Install the Rojo Studio plugin: `rojo plugin install`.
3. Clone this repo, then from the repo folder run:

   ```bash
   rojo serve
   ```

4. In Studio, open the shared place, open the **Rojo** plugin tab and click **Connect**. Edits to files in `src/` now sync live into Studio.

## Workflow

- Edit code in `src/` (not in Studio's script editor — Studio-side edits to synced scripts get overwritten).
- Pull before you start, commit small, push often.
- For bigger changes, use a branch and open a pull request.
