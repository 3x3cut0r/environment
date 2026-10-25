---
description: Run tests or static checks with framework detection (scope=, path=, static=, fail-fast=)
agent: test-runner
---

Input arguments: $ARGUMENTS

Rules:
1. Parse optional overrides from `$ARGUMENTS` in `key=value` form:
   - `scope=changed|all|path` (default: `changed`)
   - `path=<target>` (required when `scope=path`; file, directory, or package)
   - `static=true|false` (default: `false`; run static checks only, no test suite)
   - `fail-fast=true|false` (default: `true`; stop after the first failing suite)
2. Treat remaining non-`key=value` free text in `$ARGUMENTS` as an optional focus instruction.
3. Scope behavior:
   - `changed`: if git is available, scope the run to changed files when the framework supports it (pytest <path>, go test ./<pkg>); otherwise run the default suite.
   - `all`: run the project's full default test suite.
   - `path`: run only the given target; stop with a clear error if it is missing.
4. Framework detection order: project scripts (Makefile, package.json scripts, just recipes), Python (pytest, unittest), JS/TS (jest, vitest, mocha), Go, Rust, Bash (bats), Java/Kotlin, Ruby. Prefer project-declared commands over guessed invocations.
5. If no test suite exists or `static=true`, fall back to static checks (bash -n, shellcheck, py_compile, ruff, tsc --noEmit, eslint, go build, go vet).
6. Safety (fixed rules):
   - Never run commands that mutate the environment, install packages, or reach production endpoints.
   - No long benchmarks or end-to-end suites by default; prefer unit tests.
   - Respect project timeouts and resource limits.
7. `fail-fast=true`: stop after the first failing suite and report it. `fail-fast=false`: run all detected suites.

Output requirements:
- Return detected framework(s) and command(s) used.
- Return commands actually executed with exit codes.
- Return failures with trimmed relevant output excerpts.
- Return commands recommended but not run and why.
- Explicit note if only static checks were performed.
