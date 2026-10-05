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

## Notes

- Code lives in `src/` and is synced into Studio by Rojo; don't edit synced scripts in Studio's script editor.
- Files are UTF-8 without BOM. Windows PowerShell 5.1 `Get-Content` misreads them (em dashes show as `â€”`) — use the Read tool or Bash instead.
