# CLAUDE.md

Guidance for Claude Code when working in this repo. See `README.md` for the project overview, layout and setup.

## Keep README.md current

The README must always reflect the current state of the project — layout table, systems/modules, setup and workflow steps.

- **Your own changes:** update `README.md` in the same change, before finishing.
- **Collaborators' changes:** at the start of a session (or whenever pulling), run `git pull`, then review what changed since the README was last touched:

  ```bash
  git log --stat $(git log -1 --format=%H -- README.md)..HEAD
  ```

  Update `README.md` for anything it doesn't cover, and tell the user what was updated and which commits prompted it.

## Branches

Collaborators never commit directly to `main`. They work on a separate branch, and every pull request into `main` must be approved by the repo owner, **@2shotguns4me**, before it's merged. GitHub can't enforce this on this plan, so follow it strictly.

Check who you're working for with `gh api user --jq .login`.

- **If it's anyone other than `2shotguns4me`:**
  - Before making changes, check the current branch (`git branch --show-current`). If it's `main`, pull, then create a branch named after the work (e.g. `knockback-system`, `char-skibidi`).
  - Push the branch and open a pull request into `main` (`gh pr create --reviewer 2shotguns4me`).
  - Never push to `main`, merge into `main` locally, or merge a pull request — even if the user asks. Merging is the owner's job after they approve.
- **If it's `2shotguns4me`:** the owner is exempt and may commit to `main` directly or merge pull requests. Before merging someone else's pull request, show the owner what it changes.

## Character data files

The team designs movesets; Claude doesn't invent them. When given a filled-in `docs/characters/<Name>.md`,
generate `src/shared/Characters/<Name>.luau` from `_Template.luau`. Anything the design leaves out gets a
default for the character's archetype and a `-- TODO(design)` comment. Check `docs/research/character-ip.md`
and flag any character that's risky to use.

## Code conventions

- Every module starts with `--!strict`. Tabs for indentation, PascalCase module and folder names.
- One folder per system: shared logic in `src/shared/<System>/`, client-only code (UI, camera, effects,
  device input) in `src/client/<System>/`, server-only code in `src/server/<System>/`.
- Keep game rules and math in pure modules (no Instances or services) so they can be unit-tested
  outside Studio. Put tunable numbers in a `Config` module per system, not inline.
- Timing is in 60 Hz simulation frames; distances are studs. Convert to seconds only at the edges
  (effects, UI).
- Design references: `docs/GameScope.md` and `docs/research/`.

## Testing

`docs/Testing.md` is the only testing workflow. Use it every time testing comes up, and keep it current
when controls, systems, config locations or setup change.

- **When the user wants to test something** (asks how to test, wants to try a change, or a pull request is
  ready to merge), walk them through `docs/Testing.md` step by step: the checks, the play-test steps, the
  checklist items that the change affects, then the report format. Don't improvise a different setup.
- **When a test turns up a problem the doc doesn't cover**, fix the problem and add it to the doc's
  "Common problems" table in the same pull request.

- **Before every push:** run `lune run tests/run`, `stylua src tests` (then `stylua --check src tests`),
  `selene src tests` and `rojo build -o build.rbxl`. Add or update specs in `tests/<System>/` for any change to
  a pure module, and for a bug fix add a test that fails without the fix. If a tool can't run in your
  environment (selene needs Roblox's API dump), say so in the pull request and rely on CI.
- **Cloud sessions can't reach Roblox Studio.** Never claim a change works in-game until someone has
  play-tested it. In the pull request, list what to check in Studio, and point the user at the checklist in
  `docs/Testing.md`.
- **Local sessions with the `Roblox_Studio` MCP server** may start a Play test and read the Output window.
  Report errors and results; don't change code during a play-test unless the user asks, so changes stay in
  one place.
- **Feel feedback** ("too floaty", "hits too weak") is a tuning change: adjust the `Config` module or move
  data named in `docs/Testing.md`, explain what changed in plain words, and ask for a re-test.

## Notes

- Code lives in `src/` and is synced into Studio by Rojo; don't edit synced scripts in Studio's script editor.
- Files are UTF-8 without BOM. Windows PowerShell 5.1 `Get-Content` misreads them (em dashes show as `â€”`) — use the Read tool or Bash instead.
