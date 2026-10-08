# TWDxOSOptimisation — CLAUDE.md

All knowledge about this repo lives in the **TWDxMCP** MCP server. This file only says which calls to make; do not add project documentation here.

Use only the TWDxMCP server for memory in this repo — project and workspace are both `TWDxOSOptimisation` (`proj_7bedbb13081a`, `ws_9a27d0fed8b6`).

## Session start

1. `load_context` with topic `TWDxOSOptimisation`.
2. `entry_manage action=get` for the canonical nodes the task needs (read 1 always; read 6 before any change):

| # | Node | ID |
|---|---|---|
| 1 | Overview, status, commands, CI, layout + code map, task → file map, history | `bf7955c6-8993-44a1-80fa-c67c185c2e38` |
| 2 | platforms/linux-debian architecture | `add81003-db36-409e-ad31-03631509b562` |
| 3 | platforms/linux-rhel architecture | `548993a9-c6ea-4c4e-be8f-6964225b8c44` |
| 4 | platforms/macos architecture | `f86fb9b6-6382-4750-8984-6ded5a89cd9e` |
| 5 | platforms/windows architecture | `edff1243-714e-4562-a892-574e5ec6f1fb` |
| 6 | Conventions, preflight tooling, security invariants | `d52389ec-8dba-4cc5-8f11-626d0b2cd6d8` |
| 7 | Known issues and changelog | `24ef3e08-5c34-4e2a-ae31-9754e8df5f33` |

3. For anything else: `memory_read action=recall` with `workspace_id: ws_9a27d0fed8b6`.

## While working

- Each `platforms/<name>/` folder is independent — never share code between them (node 6).
- Run `bash .claude/scripts/preflight.sh` before committing; enable the hook once per clone with `git config core.hooksPath .husky`.
- After a change that alters what a node says, update that node with `entry_manage action=update` (full replacement text) — never create a near-duplicate. `memory_write remember` auto-merges similar entries, so create new nodes as a short stub and fill them with `entry_manage update`.
- After a fixed CI failure: `bash .claude/scripts/learn-from-ci.sh --ci-log <log>` and log the fix in node 7.
- Save other durable facts with `memory_write action=remember`, `workspace_id: ws_9a27d0fed8b6`.
- Call `session_learn` (topic `TWDxOSOptimisation`) without being asked after each merged PR, release or significant decision/fix, and before the session ends.
- Never store secrets. Make MCP calls a few at a time (bursts of ~10 parallel calls hit the zone rate limit, error 1015).
