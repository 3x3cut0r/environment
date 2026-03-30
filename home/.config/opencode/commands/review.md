---
description: Review staged or working changes for commit readiness
agent: build
---

Input arguments: $ARGUMENTS

Repository probe and change overview:
!`if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then echo "VCS=git"; git status --short; echo "__STAGED_DIFF__"; git diff --cached; echo "__UNSTAGED_DIFF__"; git diff; elif svn info >/dev/null 2>&1; then echo "VCS=svn"; svn status; echo "__SVN_DIFF__"; svn diff; else echo "VCS=none"; fi`

Rules:
1. Parse optional overrides from `$ARGUMENTS` in `key=value` form:
   - `target=staged|all` (default: `staged`)
   - `strict=true|false` (default: `false`)
2. Detect VCS from probe output (`VCS=git`, `VCS=svn`, `VCS=none`).
3. If `VCS=none`: stop and report that neither git nor svn repository was detected.
4. Review scope selection:
   - If `target=staged` and `VCS=git`: review only staged changes (`git diff --cached`).
   - If `target=all` and `VCS=git`: review staged + unstaged changes.
   - If `VCS=svn`: review current working changes (`svn diff`) regardless of `target`.
5. Produce a concise file-by-file review summary.
6. Add findings using severity levels:
   - `blocking`: must be fixed before commit.
   - `warning`: should be fixed soon.
   - `info`: optional improvement.
7. Always check for common commit blockers in changed content:
   - Potential secrets/credentials/tokens in diffs.
   - Leftover debug artifacts (for example debug prints/logs or temporary code).
   - Obvious risky changes without safeguards (for example removed validation or error handling).
8. If repo checks are discoverable (for example lint or test scripts), run relevant quick checks and include key failures in findings.
9. Final decision:
   - Return `FAIL` if one or more `blocking` findings exist.
   - Return `PASS` if no `blocking` findings exist.
10. `strict` behavior:
   - If `strict=true`, treat all `warning` findings as `blocking` for the final decision.

Output requirements:
- Return the review scope used (`target` and effective diff source).
- Return findings grouped by severity with file references where possible.
- Return final decision: `PASS` or `FAIL`.
