---
description: Draft a Jira ticket proposal from current changes
agent: build
---

Input arguments: $ARGUMENTS

Repository probe and change overview:
!`if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then echo "VCS=git"; echo "BRANCH=$(git rev-parse --abbrev-ref HEAD)"; echo "GIT_USER_NAME=$(git config user.name)"; echo "GIT_USER_EMAIL=$(git config user.email)"; echo "__UNSTAGED_STATUS__"; git status --short; echo "__UNSTAGED_DIFF__"; git diff; elif svn info >/dev/null 2>&1; then echo "VCS=svn"; echo "SVN_URL=$(svn info --show-item url 2>/dev/null)"; echo "SVN_USER=$(whoami)"; echo "__SVN_STATUS__"; svn status; echo "__SVN_DIFF__"; svn diff; else echo "VCS=none"; fi`

Rules:
1. Parse optional overrides from `$ARGUMENTS` in `key=value` form:
   - `commits=today|branch` (default: `today`)
   - `user=<name-or-email>` (default: current user from VCS config)
   - `untracked=true|false` (default: `true`, git only)
2. Detect VCS from probe output (`VCS=git`, `VCS=svn`, `VCS=none`).
3. If `VCS=none`: stop and report that neither git nor svn repository was detected.
4. Build commit context according to `commits` mode:
   - `today`: use commits from today (since local midnight) from current user.
   - `branch`: use commits from the currently checked out branch/working copy from current user.
5. Current user resolution:
   - Git default user: `git config user.name` and `git config user.email`.
   - SVN default user: `whoami`.
   - If `user=` is set, it overrides the detected user for commit filtering.
6. Commit collection behavior:
   - Git + `today`: collect commit subjects and bodies via `git log --since=midnight --author=<resolved-user>`.
   - Git + `branch`: collect commits from current branch only:
     - Determine current branch from `HEAD`.
     - If branch has upstream, compute fork point (`merge-base --fork-point`, fallback `merge-base`) and collect `<base>..HEAD`.
     - If no upstream/fork point exists, use current branch history and filter by resolved user.
   - SVN + `today`: collect `svn log` entries since today 00:00 for current working-copy URL, filtered by resolved user.
   - SVN + `branch`: collect `svn log` for the currently checked out working-copy URL with `--stop-on-copy`, filtered by resolved user.
7. Include all unstaged changed files in analysis:
   - Git: include modified/deleted unstaged files and, if `untracked=true`, include untracked files as well.
   - SVN: include all working-copy changes from `svn status`/`svn diff`.
8. Use both data sources (commit context + unstaged changes) to infer exactly one Jira proposal with these fields:
   - `typ` (one of `aufgabe`, `story`, `bug`, `unteraufgabe`; never `epic`)
   - `zusammenfassung` (short, specific, action-oriented)
   - `beschreibung` (concise but complete: context, current behavior, target behavior, and implementation notes)
9. Selection guidance for `typ`:
   - `bug`: fixes incorrect behavior, regressions, crashes, or defects.
   - `story`: delivers user-visible value or new capability.
   - `aufgabe`: technical/operational work not directly user-facing.
   - `unteraufgabe`: scoped child work item of a larger known ticket.
10. If no commits are found for the selected scope/user, still create a proposal from unstaged changes and note the missing commit context.
11. Keep output in German unless input arguments explicitly request another language.

Output requirements:
- Return `vcs`, `commits_mode`, `resolved_user`, and `analysed_branch_or_url`.
- Return a short `analysebasis` line with commit count and unstaged file count used.
- Return exactly one Jira proposal block with:
  - `typ:`
  - `zusammenfassung:`
  - `beschreibung:`
