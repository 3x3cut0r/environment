---
description: Create, review, simplify, or expand a README
agent: build
---

Input arguments: $ARGUMENTS

Rules:
1. Parse optional overrides from `$ARGUMENTS` in `key=value` form:
   - `mode=apply|check|simplify|expand` (default: `apply`)
   - `length=short|medium|long` (default: `medium`)
   - `audience=users|developers|both` (default: `both`)
   - `path=<path-to-readme>` (default: `./README.md`)
2. This command must work without git or svn. Do not require repository detection.
3. Operate on the resolved README target file only.
4. Content safety and quality constraints:
   - Use only information that is verifiable from files in the current workspace.
   - Do not invent features, commands, dependencies, or operational guarantees.
   - Do not add secrets, credentials, private URLs, or tokens.
   - Keep commands copy/paste-ready and use relative links.
5. Mode behavior:
   - `apply`: Create missing README or conservatively update existing README while preserving useful structure.
   - `check`: Analyze only. Do not modify files. Report gaps, stale parts, and concrete recommendations.
   - `simplify`: Requires existing README. Shorten and clarify text, remove redundancy, keep essential sections and factual accuracy.
   - `expand`: Create missing README or make existing README more detailed with practical depth (examples, configuration notes, troubleshooting, and constraints where supported).
6. If the target file is missing:
   - `apply` or `expand`: create it.
   - `check`: report missing file and include a proposed section outline.
   - `simplify`: stop with a clear message that simplification requires an existing README.
7. Length behavior:
   - `short`: concise and skimmable.
   - `medium`: balanced default detail.
   - `long`: deeper operational detail and examples.
8. Audience behavior:
   - `users`: prioritize setup, usage, and quickstart clarity.
   - `developers`: prioritize architecture, development workflow, and contribution guidance.
   - `both`: keep balanced coverage for users and contributors.
9. Maintain stable structure when possible. Prefer targeted edits over large rewrites unless mode explicitly implies stronger transformation (`simplify` or `expand`).

Output requirements:
- Return the effective parameters used (`mode`, `length`, `audience`, `path`).
- Return status: `created`, `updated`, `unchanged`, or `failed`.
- Return a concise list of changed or recommended sections.
- For `check`, include a prioritized action list.
