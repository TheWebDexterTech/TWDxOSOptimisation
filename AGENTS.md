# AGENTS.md

This project's agent-facing documentation lives in [`CLAUDE.md`](CLAUDE.md) — read that file first.

It documents the per-platform folder structure under `platforms/`, the
project-wide philosophy (each platform is independently maintained — no
shared abstraction, no dispatcher script), the repo-wide commit preflight
workflow, and where each platform's install/uninstall/harden/cleanup logic
lives. Each platform folder additionally has its own `CLAUDE.md` with
implementation-level detail specific to that platform.
