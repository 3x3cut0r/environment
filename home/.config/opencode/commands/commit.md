---
description: Create a Conventional Commit for git or svn (type=, scope=, untracked=, track=, push=)
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
   - `untracked=ask|true|false` (default: `ask`)
   - `track=<path>` (optional; stage one explicitly specified untracked file)
   - `confirm=true|false` (default: `false`; when `true`, require confirmation before commit)
   - `push=true|false` (default: `true`; git only, pushes after a successful commit)
   - `desc="short summary"`
   - `body="longer explanation"`
   - `refs=<token>` (append to headline in parentheses, for example `#123` -> `... (#123)`)
2. Detect VCS from probe output (`VCS=git`, `VCS=svn`, `VCS=none`).
3. Generate a message that follows Conventional Commits 1.0.0 exactly:
   - Header: `<type>[optional scope][!]: <description>`
   - Optional body after one blank line.
   - Optional footer(s) after one blank line.
   - If `refs` is provided, append it at the end of the header in parentheses.
     - Single ref: `type(scope): description (#123)`
     - Multiple refs: `type(scope): description (#123, #456)`
   - If `breaking=true`, include `!` in header and add `BREAKING CHANGE: ...` footer when details are available.
4. If no explicit args are given, infer type/scope/description from the diff and keep the description concise.
5. Before committing, print a preview of the final message (header/body/footer).
6. Confirmation behavior:
   - Default is `confirm=false`: commit immediately after preview.
   - If `confirm=true`: ask for explicit confirmation before committing.
   - If confirmation is declined: stop without creating a commit.
7. Untracked file behavior for git:
     - Default is `untracked=ask`: if untracked files exist, list them and ask whether to include them.
     - If `untracked=true`: stage untracked files before commit.
     - If `untracked=false`: never stage untracked files automatically.
     - Always refuse to auto-stage likely sensitive or artifact paths (for example `.env*`, `*.pem`, `*.key`, `*.p12`, `id_rsa*`, `credentials*`, `*.log`, `node_modules/`, `dist/`, `build/`, `.cache/`) unless explicitly and individually confirmed.
8. `track` behavior (git and svn):
    - If `track=<path>` is provided, attempt to add exactly this file to version control before commit.
    - If the path does not exist, stop with a clear error.
    - If the path is already tracked/versioned, continue and report that no add step was needed.
    - If the path looks sensitive or like a build artifact (same patterns as above), require explicit one-time confirmation before adding.

Execution:
- If `VCS=none`: stop and report that neither git nor svn repository was detected.
- If `VCS=git`:
  - If `track=<path>` is set, process it first:
    - If file exists and is untracked, run `git add -- <path>` (after required sensitive-path confirmation).
    - If file exists but is already tracked, continue without `git add` and note it.
  - Determine untracked files first via `git status --porcelain`.
  - If there are no staged changes but tracked modifications exist, run `git add -u`.
  - Apply `untracked` behavior to untracked files explicitly:
    - `untracked=true`: stage all allowed untracked files.
    - `untracked=false`: stage none.
    - `untracked=ask`: prompt once with the file list; stage only if confirmed.
  - If `untracked=true` is set, never print or enforce "Do not auto-add untracked files".
  - If there is still nothing to commit, stop with a clear message.
  - Respect `confirm` behavior before running the commit.
  - Commit with the generated message.
  - Unless `push=false`, push after a successful commit via `git push`.
    - If no upstream is configured for the current branch, stop with a clear push error and guidance.
    - Do not attempt any push when the commit failed or was skipped.
- If `VCS=svn`:
  - If `track=<path>` is set, process it first:
    - If file exists and is not versioned, run `svn add -- <path>` (after required sensitive-path confirmation).
    - If file exists but is already versioned, continue without `svn add` and note it.
  - Commit only already versioned changes.
  - Do not auto-run `svn add` for any files except explicitly requested via `track=`.
  - If there are no changes, stop with a clear message.
  - Respect `confirm` behavior before running the commit.
  - Commit with the generated message.

Output requirements:
- Return the final commit message used.
- Return whether `track` was requested and, when applicable, whether add succeeded or was skipped.
- Return the commit result summary (revision/sha and changed file count).
- Return whether `push` was requested and, when attempted, a short push result summary.
