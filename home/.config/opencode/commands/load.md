---
description: Load TASKS.md context and optionally execute an instruction (path=, instruction=, strict=)
agent: build
---

Input arguments: $ARGUMENTS

Rules:
1. Parse optional overrides from `$ARGUMENTS` in `key=value` form:
   - `path=<path-or-pattern>` (optional, can be provided multiple times)
   - `instruction=<free-text-instruction>` (optional)
   - `strict=true|false` (default: `false`)
2. Treat remaining non-`key=value` free text in `$ARGUMENTS` as an optional inline instruction.
3. Instruction precedence:
   - If `instruction=` is provided, use it.
   - Else, use remaining free text.
4. Path resolution behavior:
   - If no `path` is provided, use default `./TASKS.md`.
   - If `path` is provided multiple times, resolve all values in argument order.
   - Support wildcard patterns in `path` values (for example `TASK*.md`, `notes/*.md`).
   - Also accept comma-separated entries inside one `path=` value (for example `path=TASKS.md,NOTES.md`).
   - Deduplicate resolved files while preserving first-seen order.
5. Read all resolved target files and synthesize one combined working context for this session, including:
   - objective and current state
   - constraints/instructions to preserve
   - decisions and assumptions
   - pending tasks and priorities
   - risks/open questions
6. Missing file and empty-match behavior:
   - If an explicit non-pattern path does not exist, treat it as missing.
   - If a wildcard pattern matches no files, report an empty match for that pattern.
   - If nothing resolves at all, stop with clear error and suggested next action (`/save` first or adjust `path=`).
7. `strict` behavior:
   - `strict=true`: fail if any explicit path is missing, any pattern is empty, or expected sections are missing.
   - `strict=false`: continue with best-effort extraction from resolved files and note missing paths/patterns/sections.
8. If an instruction is present (inline free text or `instruction=`), execute it after loading context and treat loaded context as active guidance for the task.
9. Do not invent facts that are not present in file content or current workspace evidence.

Output requirements:
- Return effective parameters used (`paths_input`, `paths_resolved`, `strict`, `instruction_used`).
- Return load status: `loaded`, `loaded_and_executed`, or `failed`.
- Return a concise context digest.
- Return per-file coverage notes and, when relevant, missing-path or empty-pattern notes.
- If instruction was provided, include execution result summary.
