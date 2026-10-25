---
description: Security audit of diff, repo, or path (scope=, path=, skill=)
agent: security-auditor
---

Input arguments: $ARGUMENTS

Repository probe and change overview:
!`if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then echo "VCS=git"; git status --short; echo "__STAGED_DIFF__"; git diff --cached; echo "__UNSTAGED_DIFF__"; git diff; else echo "VCS=none"; fi`

Rules:
1. Parse optional overrides from `$ARGUMENTS` in `key=value` form:
   - `scope=diff|repo|path` (default: `diff`)
   - `path=<folder-or-file>` (required when `scope=path`)
   - `skill=true|false` (default: `true`; load the security-officer skill as audit checklist)
2. Treat remaining non-`key=value` free text in `$ARGUMENTS` as an optional focus instruction.
3. Scope behavior:
   - `diff`: audit staged and unstaged changes from the probe output.
   - `repo`: audit the whole repository/workspace (structure, configs, dependencies, scripts).
   - `path`: audit only the given target; stop with a clear error if it is missing.
4. If `skill=true`, load the `security-officer` skill via the `skill` tool FIRST and apply its check fields (Prueffelder) as the audit checklist. Fallback if unavailable: audit universally across secrets, injection, auth, network, permissions, dependencies, data exposure, container security, and unsafe defaults.
5. Delegate repository discovery beyond the provided diff or one named file to `explore` instead of searching yourself.
6. For each finding report: file:line reference, risk level (critical/high/medium/low), one-sentence issue description, concrete remediation.

Output requirements:
- Return the audit scope used and whether the skill was loaded.
- Return findings grouped by risk level with file:line references.
- Return a summary: total findings per risk level and an overall risk verdict.
