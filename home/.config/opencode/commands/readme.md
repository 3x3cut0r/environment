---
description: Create, review, simplify, or expand a README (mode=, length=, audience=, path=, instruction=)
agent: docs-writer
---

Input arguments: $ARGUMENTS

Rules:
1. Parse optional overrides from `$ARGUMENTS` in `key=value` form:
   - `mode=apply|check|simplify|expand` (default: `apply`)
   - `length=short|medium|long` (default: `medium`)
   - `audience=users|developers|both` (default: `both`)
   - `path=<path-to-readme-or-directory>` (default: `./README.md`)
   - `instruction=<free-text-instruction>` (optional)
2. Treat remaining non-`key=value` free text in `$ARGUMENTS` as an optional inline instruction.
3. Instruction precedence:
   - If `instruction=` is provided, use it.
   - Else, use remaining free text.
4. Path resolution behavior:
   - If `path` resolves to an existing directory, target `README.md` inside that directory.
   - If `path` ends with `/` (or platform-equivalent separator), treat it as a directory path and target `<path>/README.md`.
   - Otherwise, treat `path` as a file path (for example `docs/README.md`, `docs/Guide.md`).
   - If no `path` is provided, target `./README.md`.
   - Operate on the resolved target file only.
5. Load/use the `readme` skill before doing README-specific analysis or edits. Treat the skill as the canonical README policy for structure, content safety, and conservative update behavior.
6. This command must work without git or svn. Do not require repository detection.
7. Mode behavior:
     - `apply`: Create missing README or conservatively update existing README while preserving useful structure.
     - `check`: Analyze only. Do not modify files. Report gaps, stale parts, and concrete recommendations.
     - `simplify`: Requires existing README. Shorten and clarify text, remove redundancy, keep essential sections and factual accuracy.
     - `expand`: Create missing README or make existing README more detailed with practical depth (examples, configuration notes, troubleshooting, and constraints where supported).
8. If an instruction is present (inline free text or `instruction=`), apply mode behavior to the instruction scope only (targeted task) instead of full-document broad updates.
9. If the target file is missing:
    - `apply` or `expand`: create it.
    - `check`: report missing file and include a proposed section outline.
    - `simplify`: stop with a clear message that simplification requires an existing README.
10. Length behavior:
    - `short`: concise and skimmable.
    - `medium`: balanced default detail.
    - `long`: deeper operational detail and examples.
11. Audience behavior:
    - `users`: prioritize setup, usage, and quickstart clarity.
    - `developers`: prioritize architecture, development workflow, and contribution guidance.
    - `both`: keep balanced coverage for users and contributors.
12. Maintain stable structure when possible. Prefer targeted edits over large rewrites unless mode explicitly implies stronger transformation (`simplify` or `expand`).

Output requirements:
- Return the effective parameters used (`mode`, `length`, `audience`, `path`, `instruction_used`).
- Return status: `created`, `updated`, `unchanged`, or `failed`.
- Return a concise list of changed or recommended sections.
- For `check`, include a prioritized action list.
