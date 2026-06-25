# AGENTS.md
## Scope
This repository is a Bash-first workstation bootstrap and dotfiles repo.
The main executable is `setup.sh`.
Most other tracked files are shell snippets, Neovim config, theme assets, and helper data under `home/`, `vars/`, and `sources/`.
Prefer small, targeted edits and do not invent tooling that does not exist here.

## Local Rule Files
Cursor:
- No `.cursor/rules/` directory found.
- No `.cursorrules` file found.
Copilot:
- No `.github/copilot-instructions.md` file found.
There are no repository-local Cursor or Copilot instructions beyond this file.

## Repository Map
- `setup.sh`: main bootstrap script.
- `packages.list`: package definitions used by `install_packages`.
- `home/`: dotfile fragments copied or merged onto the target system.
- `vars/`: prompt and merge helper snippets.
- `sources/`: bundled fallback archives.
- `README.md`: user-facing documentation.

Important conventions:
- `*.append` files are appended into target files.
- `*.touch` files ensure target files exist.
- Marker comments like `# <<< vars/PATH` are merge anchors.
- `packages.list` is split by `# <<< Add python packages below`.
Do not rename or remove these conventions casually.

## Build, Lint, And Test Commands
There is no formal build system.
There is no automated test suite.
`README.md` explicitly says tests do not currently exist.

Core checks:
```bash
bash -n setup.sh
shellcheck setup.sh
./setup.sh --help
```
- `bash -n setup.sh`: syntax check.
- `shellcheck setup.sh`: primary shell lint command.
- `./setup.sh --help`: cheap runtime sanity check for parsing and help output.

Changed shell fragments:
```bash
shellcheck home/.bashrc.append
shellcheck home/.bash_profile.append
shellcheck home/.profile.append
shellcheck home/.zprofile.append
shellcheck home/.zshrc.append
```
Lint only the shell files you changed.

Single-test guidance:
There is no single-test runner because there is no test harness.
If asked for a single test, run the narrowest relevant validation command instead:
```bash
bash -n setup.sh
shellcheck path/to/changed-file.sh
./setup.sh --help
```
State clearly that the repo has no automated per-test or per-file test framework.

Optional manual check:
```bash
./setup.sh --reconfigure --yes
```
Run this only when the task specifically requires an end-to-end check.
It mutates the local environment.

## Tooling Signals In The Repo
- VS Code sets `esbenp.prettier-vscode` as the default formatter.
- VS Code enables `files.insertFinalNewline`.
- Neovim config expects `shellcheck`, `ruff`, and `ansible-lint`.
- Neovim LSP config expects `bashls`, `jsonls`, `yamlls`, `marksman`, `pyright`, `ansiblels`, `groovyls`, and `lua_ls`.

Interpretation:
- Shell quality matters most.
- Keep JSON, Markdown, YAML, TOML, and Lua formatting stable.
- Do not assume a repo-wide Prettier CLI command exists; only editor preference is configured.

## Code Style
General:
- Preserve existing structure unless there is a concrete reason to change it.
- Prefer minimal diffs.
- Keep comments brief and intent-focused.
- Use ASCII unless the file already uses non-ASCII text.
- End files with a trailing newline.

Shell:
- Use `#!/usr/bin/env bash` for Bash scripts.
- Use `set -euo pipefail` in standalone Bash scripts unless there is a strong reason not to.
- Use `snake_case` for functions like `install_packages`.
- Use uppercase names for global flags and config like `SKIP_PACKAGES`.
- Use `local` for function-scoped variables.
- Quote expansions unless unquoted behavior is required.
- Prefer `$(...)` over backticks.
- Prefer `printf` over fragile `echo` usage.
- Guard optional tools with `command -v ... >/dev/null 2>&1`.
- Read lines with `IFS= read -r`.
- Route user-facing script output through `log_message` when touching `setup.sh`.

Shell formatting:
- Match existing indentation: 4 spaces in `setup.sh`.
- Keep `case` arms aligned and terminated with `;;`.
- Break long commands across lines with consistent continuation indentation.
- Keep related global variable assignments grouped near the top.

Shell error handling:
- Fail fast by default.
- Validate prerequisites before destructive work.
- If a failure is intentionally tolerated, make that explicit with a guard or `|| true`.
- Prefer `log_message WARN` over silent failure.
- Preserve cleanup and trap behavior when editing temp-file handling.

Lua and Neovim config:
- Follow the existing 2-space indentation under `home/.config/nvim/`.
- Keep `require(...)` usage simple and near the top.
- Prefer direct configuration tables over unnecessary abstraction.
- Match existing names like `server_name`, `server_opts`, and `lint_augroup`.

JSON, YAML, TOML, and Markdown:
- Keep formatting stable and compact.
- Preserve key order unless reordering clearly improves clarity.
- Avoid large Markdown rewrites unless the task is documentation-focused.
- Use fenced code blocks with language tags in Markdown.

## Imports, Dependencies, And Naming
This repo has no conventional application import graph.
Dependency changes usually mean one of these:
- adding packages in `packages.list`
- invoking a new external CLI from `setup.sh`
- adding an editor plugin, linter, or LSP entry

When introducing a dependency:
- justify it
- wire it into the smallest necessary place
- keep fallback behavior consistent with existing patterns
- update docs if user-facing behavior changes
- when adding a new user-facing CLI, package, function, editor integration, pager, or similar tooling surface, check whether a matching Catppuccin theme/plugin/integration exists upstream and integrate it by default when it fits the repo's existing setup patterns

Naming conventions:
- shell functions: verb-led `snake_case`
- shell globals: uppercase with underscores
- shell locals: lowercase `snake_case`
- Lua locals: short descriptive `snake_case`
- filenames: preserve conventions like `.append`, `.touch`, and `.list`

## Editing Guidance For Agents
- Read surrounding code before editing.
- Preserve merge markers and file-role semantics.
- Avoid broad rewrites of `setup.sh`; it contains many platform branches.
- When changing package behavior, inspect both `packages.list` and `install_packages`.
- When changing merge behavior, inspect `configure_environment`, `insert_file_content`, and `determine_comment_prefix` together.
- When adding new tooling or runtime integrations, explicitly check whether a matching Catppuccin plugin/theme exists and, if it does, integrate it conservatively instead of leaving the tool unthemed.

## Verification Expectations
After shell changes, run the narrowest useful checks you can, usually:
```bash
bash -n setup.sh
shellcheck setup.sh
```
After documentation-only changes, no code validation is required.
In your final summary, separate:
- commands you actually ran
- commands you recommend but did not run
- checks unavailable because the repo has no automated tests
