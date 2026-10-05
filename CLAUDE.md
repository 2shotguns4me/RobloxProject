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

## Notes

- Code lives in `src/` and is synced into Studio by Rojo; don't edit synced scripts in Studio's script editor.
- Files are UTF-8 without BOM. Windows PowerShell 5.1 `Get-Content` misreads them (em dashes show as `â€”`) — use the Read tool or Bash instead.
