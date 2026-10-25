---
description: Generate a Keep a Changelog entry from commits (since=, unreleased=, file=, lang=)
agent: build
---

Input arguments: $ARGUMENTS

Repository probe:
!`if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then echo "VCS=git"; echo "__LAST_TAGS__"; git tag --sort=-creatordate | head -5; echo "__RECENT_LOG__"; git log --oneline -20; else echo "VCS=none"; fi`

Rules:
1. Parse optional overrides from `$ARGUMENTS` in `key=value` form:
   - `since=<tag-or-ref>` (collect commits since this ref; default: latest tag, else branch start)
   - `unreleased=true|false` (default: `true`; write entries under an Unreleased section)
   - `file=<path>` (default: `./CHANGELOG.md`)
   - `lang=en|de` (default: follow the existing changelog language, else `en`)
2. Treat remaining non-`key=value` free text in `$ARGUMENTS` as an optional focus instruction.
3. If `VCS=none`: stop and report that no git repository was detected.
4. Determine the commit range: `since=` if provided, else the latest tag from the probe, else the full history (warn before processing very large ranges).
5. Collect commits via `git log <since>..HEAD` and group them into Keep a Changelog categories: Added, Changed, Deprecated, Removed, Fixed, Security. Map Conventional Commit types when subjects follow that convention (feat->Added, fix->Fixed, docs/perf/chore->Changed, security-related->Security).
6. Write behavior:
   - If the changelog file does not exist: create it with Keep a Changelog 1.1.0 structure.
   - If it exists: insert the new entry under `## [Unreleased]` (or create that section) without rewriting existing entries.
   - Preserve existing entries, ordering, and language.
7. Keep entries factual: one bullet per commit, merged when commits describe the same change; no invented changes.

Output requirements:
- Return the commit range used and commit count.
- Return the changelog file and status: created / updated / unchanged.
- Return the generated entry (category headers with bullets).
