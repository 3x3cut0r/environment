# Global OpenCode Instructions

## Communication

- Reply to the user in German.
- Write code, identifiers, file paths, log output, commit messages, and configuration examples in English.
- Keep responses concise unless the user asks for deeper explanation.

## First steps in a repository

- Read `AGENTS.md`, `README.md`, and repo-local rule files such as `.cursorrules` and `.github/copilot-instructions.md` when present.
- Detect the stack from concrete signals: shebangs, file extensions, `package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`, `Makefile`, compose files, and formatter or linter configs.
- If no stack is detectable, assume Bash and Python as the primary defaults.
- Match existing style, naming, indentation, quoting, and file layout instead of imposing a new style.

## Planning and implementation

- In plan mode, only analyze, research, and propose changes. Do not edit files or run mutating commands.
- In build mode, prefer minimal, targeted diffs over rewrites.
- Read surrounding code before editing.
- Preserve public APIs unless the requested task is explicitly a breaking change.
- Ask a focused question when requirements are ambiguous and a wrong assumption would be costly.
- Do not leave dead code, commented-out blocks, debug prints, or unrelated formatting changes.

## Tool and research rules

- MUST use the `explore` subagent as the first step for repository or web discovery before answering architecture, configuration, or file-location questions. Prefer delegation over doing discovery in a primary agent. If a task can be split into independent subtasks, delegate them to subagents in parallel whenever that reduces latency without creating overlapping work.
- Use Context7 MCP for current documentation whenever the user asks about a library, framework, SDK, API, CLI tool, or cloud service. Start with `resolve-library-id`, then query the selected docs with the full user question.
- Do not use Context7 for refactoring, writing scripts from scratch, debugging business logic, code review, or general programming concepts.
- Include source URLs when using web research.
- Prefer file references with line numbers when making claims about code or configuration.

## Verification

- Run the narrowest useful checks for the stack touched.
- Prefer project-specific commands from `Makefile`, package scripts, `justfile`, or documented workflows when available.
- If a recommended check is unsafe, too expensive, unavailable, or intentionally skipped, say so in the final summary.

## Security

- Do not print secrets, tokens, private keys, or credential values.
- Avoid reading `.env`, credential, key, certificate, and password database files unless the user explicitly asks for a security-conscious inspection.
- If a secret appears in configuration or output, describe the risk without repeating the value.
- Treat shell commands, deserialization, network boundaries, authentication, and secret handling as security-sensitive changes.

## OpenCode configuration

- Use the documented opencode paths:
  - Global config: `~/.config/opencode/opencode.json` or `~/.config/opencode/opencode.jsonc`
  - Global instructions: `~/.config/opencode/AGENTS.md`
  - Global agents: `~/.config/opencode/agent/<name>.md` or `~/.config/opencode/agents/<name>.md`
  - Global skills: `~/.config/opencode/skills/<name>/SKILL.md`
- Validate opencode config shapes against the schema before changing JSON or JSONC config.
- After changing opencode config, agents, skills, plugins, or MCP settings, tell the user to restart opencode.
