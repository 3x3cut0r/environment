---
description: Save current session context into TASKS.md
agent: build
---

Input arguments: $ARGUMENTS

Rules:
1. Parse optional overrides from `$ARGUMENTS` in `key=value` form:
   - `path=<path-to-file>` (default: `./TASKS.md`)
   - `mode=overwrite|append` (default: `overwrite`)
   - `confirm=true|false` (default: `auto`)
2. This command must work without git or svn. Do not require repository detection.
3. Build a concise, execution-ready snapshot of the current session using available context from this conversation, including:
   - goal and requested outcomes
   - active constraints and important instructions
   - decisions already made and rationale
   - current plan/progress and status
   - open questions, risks, and assumptions
   - next concrete steps
4. Write the snapshot to the resolved target file in Markdown with stable sections.
5. File write behavior:
   - If target file does not exist: create it.
   - If target file exists and `mode=overwrite`: replace full file content.
   - If target file exists and `mode=append`: append a new timestamped session block.
6. Confirmation behavior when target file already exists:
   - `confirm=true`: always ask user confirmation before writing.
   - `confirm=false`: never ask and execute directly using selected `mode`.
   - `confirm=auto` (default):
     - if `mode` was explicitly provided by user, execute directly.
     - if `mode` was not explicitly provided, warn and ask user whether to `overwrite` or `append`.
7. When asking confirmation, present exactly these choices:
   - `overwrite`
   - `append`
   - `cancel`
   If user chooses `cancel`, stop without modifying files.
8. Keep content factual and grounded in available conversation/workspace evidence.

Output requirements:
- Return effective parameters used (`path`, `mode`, `confirm`).
- Return write status: `created`, `overwritten`, `appended`, `cancelled`, or `failed`.
- Return a short list of included sections.
