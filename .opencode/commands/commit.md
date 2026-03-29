---
description: Create a Conventional Commit for git or svn
agent: build
---

Input arguments: $ARGUMENTS

Repository probe and change overview:
!`if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then echo "VCS=git"; git status --short; echo "__STAGED_DIFF__"; git diff --cached; echo "__UNSTAGED_DIFF__"; git diff; elif svn info >/dev/null 2>&1; then echo "VCS=svn"; svn status; echo "__SVN_DIFF__"; svn diff; else echo "VCS=none"; fi`

Rules:
1. Parse optional overrides from `$ARGUMENTS` in `key=value` form:
   - `type=<feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert>`
   - `scope=<name>`
   - `breaking=true|false`
   - `desc="short summary"`
   - `body="longer explanation"`
   - `refs=<token>` (for footer, for example `#123`)
2. Detect VCS from probe output (`VCS=git`, `VCS=svn`, `VCS=none`).
3. Generate a message that follows Conventional Commits 1.0.0 exactly:
   - Header: `<type>[optional scope][!]: <description>`
   - Optional body after one blank line.
   - Optional footer(s) after one blank line.
   - If `breaking=true`, include `!` in header and add `BREAKING CHANGE: ...` footer when details are available.
4. If no explicit args are given, infer type/scope/description from the diff and keep the description concise.
5. Before committing, print a preview of the final message (header/body/footer).

Execution:
- If `VCS=none`: stop and report that neither git nor svn repository was detected.
- If `VCS=git`:
  - If there are no staged changes but tracked modifications exist, run `git add -u`.
  - Do not auto-add untracked files.
  - If there is still nothing to commit, stop with a clear message.
  - Commit with the generated message.
- If `VCS=svn`:
  - Commit only already versioned changes.
  - Do not auto-run `svn add`.
  - If there are no changes, stop with a clear message.
  - Commit with the generated message.

Output requirements:
- Return the final commit message used.
- Return the commit result summary (revision/sha and changed file count).
