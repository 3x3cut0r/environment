---
name: opencode-setup
description: "Use for maintaining this opencode setup: creating or editing agents, commands, skills, or the opencode.jsonc config. Covers description conventions, color and model assignment, repo mirror sync rules, v1 compatibility constraints, and command style. Trigger on opencode configuration, agent, subagent, skill, or command maintenance tasks."
compatibility: opencode
---

# Rolle
Wissensbasis fuer die Pflege dieser opencode-Konfiguration (opencode v1).
Alle Regeln hier sind verbindliche Konventionen fuer Aenderungen an Agents,
Commands, Skills und der Config.

# Sprach-Regeln
- Descriptions (Agents, Skills, Commands): immer ENGLISCH, dritte Person,
  "Use when..."-Muster mit Trigger-Keywords und Abgrenzung ("Do NOT use for
  X (Y)").
- Agent-Prompt-Bodies: englisch, mit "Reply to the user in German"-Instruktion.
- Skill-Bodies: duerfen deutsch sein (ASCII-Umlaute ue/ae/oe).
- Antworten an den User: deutsch. Code, Identifier, Kommentare: englisch.

# Agenten-Konventionen
- `model` und `variant` NIEMALS in Agent-Dateien definieren - nur im
  `agent`-Block der opencode.jsonc (Markdown-Dateien gewinnen sonst gegen die
  Config und Modelle waeren nicht pro Umgebung ueberschreibbar).
- Colors nach Faehigkeiten: `error` = edit-faehig (build, general, docs-writer),
  `warning` = bash-faehig ohne edit (debugger, test-runner, log-analyzer),
  `info` = pure read-only (explore, code-reviewer, security-auditor), plan
  ohne Color (Default).
- `subagent_depth: 2` (Top-Level in der Config, v1-nativ) - Subagents koennen
  an explore delegieren.
- `plan` hat `general: deny` im task-Block (uebersteuert den Built-in-Default
  fuer Primary-Agents) und keine write-faehigen Subagents.
- `scout.md` ist ein Tombstone (`disable: true`) - Scout existiert in v1.19.x
  nicht mehr als Built-in; die Datei bleibt als Schutz, falls er zurueckkehrt.
- Agent-Frontmatter: nur gueltige v1-Felder (description, mode, color,
  temperature, steps, permission, disable).

# v1-Kompatibilitaet (KEINE v2-Felder verwenden)
- Config-Key: `agent` (Singular), nicht `agents`.
- Feld: `disable` (nicht `disabled`).
- Permission-Key: `permission` (nicht `permissions` - hartes Startversagen!).
- `subagent_depth` auf Top-Level der Config, nicht unter `experimental`.
- Background-Subagents benoetigen
  OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS=true (in ~/.zshrc gesetzt).

# Sync-Regel (live <-> Repo)
- ALLES unter ~/.config/opencode/ wird in den Repo-Spiegel
  ~/github/environment/home/.config/opencode/ synchronisiert: agents/,
  commands/, skills/, opencode.jsonc.default (opencode.jsonc ist ein Symlink
  auf .default).
- Externe Skills (~/.agents/skills/, ~/.claude/skills/) werden NICHT
  gespiegelt - sie haben eigene Update-Mechanismen (hf skills add --force,
  npx ctx7 skills install).
- Nach jeder Aenderung: `diff -r` live vs. Repo als Verifikation.

# Command-Stil
- Frontmatter: `description` (mit Parameter-Hinweisen in Klammern),
  `agent: <name>`.
- Body: "Input arguments: $ARGUMENTS", optional `!`-Probe (Shell-Ausfuehrung
  zur Command-Render-Zeit), "Rules:" (key=value-Parsing zuerst, dann
  Verhalten), "Output requirements:" am Ende.
- Sprache: englisch.

# Sonstiges
- Config wird nicht hot-reloaded: nach Aenderungen opencode neu starten.
- Verifikation: `opencode debug agent <name>`, `opencode agent list`,
  `opencode debug config`, `opencode debug skill`.
