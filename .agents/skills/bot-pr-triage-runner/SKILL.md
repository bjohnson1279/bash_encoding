---
name: bot-pr-triage-runner
description: >-
  Audits, categorizes, syncs stale bases, and batch-processes open Pull Requests from automated bots
  across GitHub repositories and local multi-workspace directories with mandatory user confirmation.
---

# Bot PR Triage & Batch Merge Runner

## Overview
Automates the discovery, categorization, workspace mapping, and batch processing of open Pull Requests from automated bots (Bolt, Sentinel, Dependabot, Jules) across an entire GitHub account or within specific multi-repository submodules.

---

## Dependencies
- **GitHub CLI (`gh`)** authenticated (`gh auth status`)
- **Python 3.8+** (uses standard library `subprocess`, `json`, `pathlib`, `argparse`)
- **Git**

---

## Quick Start

```bash
# 1. Discover all open bot PRs across all owner repositories
python .agents/skills/bot-pr-triage-runner/scripts/triage_runner.py discover-all \
  --owner bjohnson1279 \
  --output open_prs.json

# 2. Correlate discovered PRs with local workspace folders / submodules
python .agents/skills/bot-pr-triage-runner/scripts/triage_runner.py map-workspaces \
  --prs-file open_prs.json \
  --dev-root C:/Users/johns/DEV \
  --output pr_workspace_map.json

# 3. Audit PRs into triage groups
python .agents/skills/bot-pr-triage-runner/scripts/triage_runner.py audit \
  --input-file open_prs.json \
  --output triage_groups.json
```

---

## Utility Scripts

The CLI script `triage_runner.py` provides:

### 1. `discover-all`
Searches all repositories owned by a user/org, extracting mergeability (`MERGEABLE` vs `CONFLICTING`) and CI check rollups (`SUCCESS` vs `FAILURE`).

```bash
python .agents/skills/bot-pr-triage-runner/scripts/triage_runner.py discover-all \
  --owner bjohnson1279 \
  --output open_prs.json
```

### 2. `map-workspaces`
Maps discovered PRs against local project trees and git submodules (`.gitmodules`) to identify where fixes should be committed or tested.

```bash
python .agents/skills/bot-pr-triage-runner/scripts/triage_runner.py map-workspaces \
  --prs-file open_prs.json \
  --dev-root C:/Users/johns/DEV \
  --output pr_workspace_map.json
```

### 3. `audit`
Categorizes PRs into:
- **Group A (Safe & High Value)**: All CI checks pass, clean diffs.
- **Group A (Needs Sync)**: Conflicting merge state requiring target branch rebase.
- **Group B (Defective / Failing CI)**: Broken tests or destructive line removals.
- **Group C (Zero-Diff / Hallucinatory)**: 0 code diffs outside `.jules/` logs.

### 4. `find-duplicates`
Analyzes open PRs across a repository to detect duplicate/competing PRs targeting the same source files or functions, identifying primary candidates and superseded PRs.

```bash
python .agents/skills/bot-pr-triage-runner/scripts/triage_runner.py find-duplicates \
  --repo bjohnson1279/bash_encoding
```

---

## Workflow

1. **Discovery**: Run `discover-all` to inventory all open bot PRs.
2. **Workspace Mapping**: Map remote PR repositories to local dev checkouts.
3. **Audit**: Categorize PRs by CI health and mergeability.
4. **Mandatory Confirmation**: Request explicit user confirmation before executing merges or closures.
5. **Batch Processing**: Synchronize stale PRs, merge Group A, and close Group B/C.

---

## Common Mistakes

1. **Merging without verifying CI status**: Always inspect `statusCheckRollup` for test failures.
2. **Executing batch merges without user confirmation**: Never auto-merge without presenting a summary table and obtaining approval.
3. **Assuming single-repo scope**: Bot PRs often target multiple submodules simultaneously (e.g. `gql-ddd-inventory`, `php-ddd-inventory`, `js-ddd-inventory`). Use `discover-all` to ensure full visibility.
