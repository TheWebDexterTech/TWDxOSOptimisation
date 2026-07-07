# TWDxOSOptimisation — Claude Context

A hands-off OS optimization, hardening, and maintenance toolkit covering
multiple operating systems. Formerly `TWDxWordPressServerSecurity` — a
WordPress-on-Ubuntu-specific tool. It has since been generalized: WP-CLI
auto-update is now an optional module inside applicable platform folders,
not the centerpiece.

---

## Philosophy — read this before touching more than one platform folder

**Each platform folder under `platforms/` is independently maintained and
deliberately does not share code with any other.** There is no shared
abstraction layer, no dispatcher script, and no "common" folder. If you're
about to factor out shared logic between, say, `linux-debian` and
`linux-rhel` — don't. The whole point of this structure is that someone can
open exactly one platform folder, read it end to end, and edit it without
needing to understand or touch the others. Some duplication across folders
(similar `install.sh` shapes, similar logging-helper functions) is the
accepted tradeoff for that independence, not an oversight to "clean up."

When asked to add a feature "for all platforms," treat that as four (or
five) separate, platform-appropriate implementations — not one shared
implementation invoked four ways.

---

## Repository Layout

```
.
├── README.md                    # Short hub/index — platform table, project pitch
├── CLAUDE.md                    # This file — thin, project-wide orientation only
├── AGENTS.md                    # Pointer to this file, for non-Claude coding agents
├── LICENSE                      # MIT, repo-wide
├── .gitignore / .claudeignore
├── .github/workflows/
│   ├── shellcheck.yml           # Lints every platforms/*/  .sh + .sh.tpl file (recursive)
│   └── powershell-lint.yml      # PSScriptAnalyzer, scoped to platforms/windows/
├── scripts/
│   └── pre-commit.sh            # Repo-wide commit preflight (see below) — the one shared file
└── platforms/
    ├── linux-debian/            # Debian/Ubuntu — original project, Bash
    ├── linux-rhel/               # RHEL/Fedora/CentOS — Bash
    ├── macos/                    # macOS — Bash + launchd
    └── windows/                  # Windows — PowerShell + Task Scheduler
```

Each platform folder has its own `README.md` (user-facing docs — env vars,
usage, verification steps) and its own `CLAUDE.md` (implementation-facing —
file map, dependency graph, conventions specific to that platform). Claude
Code loads the nearest `CLAUDE.md` automatically when working inside a
subdirectory, layered on top of this root file — so working inside
`platforms/linux-rhel/`, for instance, surfaces that folder's `CLAUDE.md`
without any extra step.

**`scripts/pre-commit.sh` is the one intentionally shared file** — it's a
repo-wide dev tool, not platform content, and is generic across platforms
by design (it discovers every `platforms/*/install.sh`'s own
`FILE_CHECKSUMS` array rather than hardcoding a file list, so adding a new
platform requires zero edits to it).

---

## Commit Preflight (workflow rule)

`main` is production. **Before every commit**, run `bash scripts/pre-commit.sh`
(or just `git commit` if the hook is symlinked — see below). It runs three
checks across the whole repo:

1. **ShellCheck** on every `.sh`/`.sh.tpl` file under `platforms/` and
   `scripts/` (matches the `shellcheck.yml` CI job; `--severity=style --format=gcc`).
   PowerShell files under `platforms/windows/` are out of scope for this
   hook — they're covered by the separate `powershell-lint.yml` CI job.
2. **`FILE_CHECKSUMS` drift** — for every `platforms/*/install.sh`, every
   file its own `FILE_CHECKSUMS` array references must match the actual
   `sha256sum` on disk.
3. **Secret scan** on the staged diff — AWS keys, GitHub tokens, OpenAI
   keys, PEM private blocks, long `password=` literals.

If any check fails: **fix the issue locally, re-run the preflight, then
commit.** Never push a failing tree to `main`.

**One-time hook install (per clone):**

```bash
ln -sf ../../scripts/pre-commit.sh .git/hooks/pre-commit
chmod +x scripts/pre-commit.sh
```

---

## Common Change Recipes

| Goal | Files to touch |
|---|---|
| Change something in one existing platform | Work entirely inside that `platforms/<name>/` folder — its own `CLAUDE.md` has the file map, dependency graph, and checksum-recompute recipe |
| Add a brand-new platform | Create `platforms/<name>/` with its own `install`/`uninstall`/`harden`/`declutter` scripts (or the closest equivalents), `configs/`, optional `modules/`, `README.md`, and `CLAUDE.md`. No other file in the repo needs to change — `scripts/pre-commit.sh` and `shellcheck.yml`'s recursive `scandir` pick it up automatically (Bash-based platforms only; a new PowerShell-based platform would need its own CI job like `powershell-lint.yml`, or an extended `-Path` on the existing one) |
| Update root docs | Keep `README.md` and this file thin — platform-specific detail belongs in that platform's own docs, not here |
| Add a CI rule | Bash: extend `shellcheck.yml`. PowerShell: extend `powershell-lint.yml`. Keep `permissions: contents: read` on both |

## What NOT to Read for Typical Tasks

| File | Skip when... |
|---|---|
| Root `README.md` | Any code task — it's a short pitch/index, not implementation. Already in `.claudeignore` |
| `LICENSE` | Always — MIT boilerplate. Already in `.claudeignore` |
| `.github/{FUNDING,dependabot}.yml` | Always — non-functional metadata |
| A platform folder you're not working in | Unless the task explicitly spans platforms (rare — see Philosophy above) |
