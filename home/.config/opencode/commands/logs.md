---
description: Analyze logs from containers, services, or files (source=, unit=, file=, since=, tail=, grep=)
agent: log-analyzer
---

Input arguments: $ARGUMENTS

Source probe:
!`echo "__DOCKER_CONTAINERS__"; docker ps --format '{{.Names}}' 2>/dev/null || true; echo "__FAILED_UNITS__"; systemctl --failed --no-legend 2>/dev/null || true`

Rules:
1. Parse optional overrides from `$ARGUMENTS` in `key=value` form:
   - `source=<container-name>` (docker container to analyze via docker logs)
   - `unit=<systemd-unit>` (systemd unit to analyze via journalctl)
   - `file=<path>` (log file to analyze)
   - `since=<time>` (default: `24h`; passed to docker logs --since / journalctl --since)
   - `tail=<n>` (default: `2000`; limit lines fetched per source)
   - `grep=<pattern>` (pre-filter lines before analysis)
2. Treat remaining non-`key=value` free text in `$ARGUMENTS` as an optional focus instruction.
3. Source resolution:
   - If `source=`, `unit=`, or `file=` is provided, use them; multiple values are allowed for cross-source correlation.
   - Else auto-detect from the probe: failed systemd units first, then running docker containers.
   - If no source resolves, stop with clear guidance to provide `source=`, `unit=`, or `file=`.
   - If a given source, unit, or file does not exist, stop with a clear error.
4. Fetching behavior (read-only commands only):
   - Docker: `docker logs <name> --tail <n> --since <time>`
   - Systemd: `journalctl -u <unit> --since <time> --no-pager`
   - Files: `tail -n <n> <file>` (resolve `~` and relative paths)
   - Apply `grep=` as a pre-filter only when provided; still search for the first error within filtered lines.
5. Apply the full log-analysis methodology: identify size and time range first, group and count error types, find the FIRST occurrence of the failure, build one timeline, redact secrets in every quoted line.
6. Do not restart, truncate, rotate, or delete anything.

Output requirements:
- Return sources analyzed with time range and line counts.
- Return timeline, error groups with counts and first-occurrence timestamps, first error excerpt (trimmed), correlations and anomalies.
- Return a hand-off note: what the debugger or caller should examine next.
