---
description: Draft a Jira proposal from changes, path, or workspace context (instruction=/inst=, context=, path=, type=, commits=, user=, untracked=)
agent: plan
---

Input arguments: $ARGUMENTS

Repository probe and change overview:
!`if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then echo "VCS=git"; echo "BRANCH=$(git rev-parse --abbrev-ref HEAD)"; echo "GIT_USER_NAME=$(git config user.name)"; echo "GIT_USER_EMAIL=$(git config user.email)"; echo "__UNSTAGED_STATUS__"; git status --short; echo "__UNSTAGED_DIFF__"; git diff; elif svn info >/dev/null 2>&1; then echo "VCS=svn"; echo "SVN_URL=$(svn info --show-item url 2>/dev/null)"; echo "SVN_USER=$(whoami)"; echo "__SVN_STATUS__"; svn status; echo "__SVN_DIFF__"; svn diff; else echo "VCS=none"; fi`

Rules:
1. Parse optional overrides from `$ARGUMENTS` in `key=value` form:
   - `instruction=<free-text-focus>` or `inst=<free-text-focus>` (optional, same meaning)
   - `context=changes|path|workspace` (default: `changes`)
   - `path=<folder-or-file>` (required when `context=path`)
   - `type=auto|task|story|bug|subtask|epic` (default: `auto`)
   - `commits=today|branch` (default: `today`)
   - `user=<name-or-email>` (default: current user from VCS config)
   - `untracked=true|false` (default: `true`, git only)
2. Detect VCS from probe output (`VCS=git`, `VCS=svn`, `VCS=none`).
3. If `VCS=none`: stop and report that neither git nor svn repository was detected.
4. Context behavior:
   - `changes` (default): keep existing behavior and prioritize commit context plus unstaged changes.
   - `path`: analyze only the given `path` target (folder or file) plus relevant VCS context. If `path` is missing or not found, stop with a clear error.
   - `workspace`: analyze the overall repository/workspace context (cross-folder view), not just current diffs.
5. Instruction behavior:
   - If `instruction`/`inst` is provided, treat it as the primary intent for what the Jira item should cover.
   - Keep the proposal grounded in verifiable repository evidence from the selected context.
6. Build commit context according to `commits` mode:
   - `today`: use commits from today (since local midnight) from current user.
   - `branch`: use commits from the currently checked out branch/working copy from current user.
7. Current user resolution:
   - Git default user: `git config user.name` and `git config user.email`.
   - SVN default user: `whoami`.
   - If `user=` is set, it overrides the detected user for commit filtering.
8. Commit collection behavior:
   - Git + `today`: collect commit subjects and bodies via `git log --since=midnight --author=<resolved-user>`.
   - Git + `branch`: collect commits from current branch only:
     - Determine current branch from `HEAD`.
     - If branch has upstream, compute fork point (`merge-base --fork-point`, fallback `merge-base`) and collect `<base>..HEAD`.
     - If no upstream/fork point exists, use current branch history and filter by resolved user.
   - SVN + `today`: collect `svn log` entries since today 00:00 for current working-copy URL, filtered by resolved user.
   - SVN + `branch`: collect `svn log` for the currently checked out working-copy URL with `--stop-on-copy`, filtered by resolved user.
9. Include unstaged working-copy changes in analysis:
   - Git: include modified/deleted unstaged files and, if `untracked=true`, include untracked files as well.
   - SVN: include all working-copy changes from `svn status`/`svn diff`.
10. Type behavior and output mapping:
   - Internal input `type` uses English values: `task`, `story`, `bug`, `subtask`, `epic`, `auto`.
   - Output field remains German `typ` with mapped values: `task->aufgabe`, `story->story`, `bug->bug`, `subtask->unteraufgabe`, `epic->epic`.
   - If `type=auto`, infer the best fitting type from evidence and intent.
11. Use the selected context + commit context + unstaged changes (as available) to infer exactly one Jira proposal with these fields:
   - `typ`
   - `zusammenfassung` (short, specific, action-oriented)
   - `beschreibung` (concise but complete: context, current behavior, target behavior, and implementation notes)
12. Selection guidance for inferred type:
   - `bug`: fixes incorrect behavior, regressions, crashes, or defects.
   - `story`: delivers user-visible value or new capability.
   - `aufgabe`: technical/operational work not directly user-facing.
   - `unteraufgabe`: scoped child work item of a larger known ticket.
   - `epic`: broad initiative that groups multiple related work items.
13. If no commits are found for the selected scope/user, still create a proposal from available context evidence and note the missing commit context.
14. Output must always be in German, regardless of input argument language.

Output requirements:
- Return `vcs`, `context`, `commits_mode`, `resolved_user`, and `analysed_branch_or_url`.
- Return `analysed_path` when `context=path`.
- Return `instruction_used` when `instruction`/`inst` was provided.
- Return `type_input` and `typ` (mapped German output value).
- Return a short `analysebasis` line with commit count and file/change evidence used.
- Return exactly one Jira proposal block with:
  - `typ:`
  - `zusammenfassung:`
  - `beschreibung:`
