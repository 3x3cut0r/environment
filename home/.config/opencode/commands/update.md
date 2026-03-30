---
description: Update working copy for git or svn
agent: build
---

Repository probe:
!`if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then echo "VCS=git"; elif svn info >/dev/null 2>&1; then echo "VCS=svn"; else echo "VCS=none"; fi`

Rules:
1. Detect VCS from probe output (`VCS=git`, `VCS=svn`, `VCS=none`).
2. If `VCS=none`: stop and report that neither git nor svn repository was detected.
3. If `VCS=git`: run `git pull`.
4. If `VCS=svn`: run `svn update`.

Output requirements:
- Return which command was executed (`git pull` or `svn update`).
- Return a short update result summary (for example new HEAD/revision and changed file count when available).
