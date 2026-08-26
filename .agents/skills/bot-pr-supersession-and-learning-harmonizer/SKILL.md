---
name: bot-pr-supersession-and-learning-harmonizer
description: >-
  Audits duplicate and competing bot Pull Requests across repositories, additively reconciles .jules/*.md
  learning notes across feature branches, and safely closes superseded PRs with clean audit references.
---

# Bot PR Supersession & Learning Harmonizer

## Overview
When automated bots (Bolt, Sentinel, Palette, Dependabot) open concurrent PRs targeting the same performance bottlenecks, bugs, or UX enhancements, multiple PRs often contain overlapping diffs and distinct learning insights recorded in `.jules/*.md` (or `.Jules/*.md`).

This skill standardizes:
1. **Duplicate & Overlap Detection**: Identifies competing PRs targeting identical code sections.
2. **Additive Learning Retention**: Merges timestamped learning notes from all candidate branches so agent learnings are never lost during PR consolidation.
3. **Audit-Safe Supersession**: Closes superseded PRs with descriptive markdown comments linking to the primary merged PR and deletes stale feature branches.

---

## Dependencies
- **GitHub CLI (`gh`)** authenticated (`gh auth status`)
- **Python 3.8+** (`argparse`, `json`, `pathlib`, `re`, `subprocess`)
- **Git**

---

## Quick Start

```bash
# 1. Detect duplicate PRs in the current repository
python .agents/skills/bot-pr-supersession-and-learning-harmonizer/scripts/supersession_harmonizer.py detect-duplicates

# 2. Additively union learning notes from a candidate feature branch into local .jules/bolt.md
python .agents/skills/bot-pr-supersession-and-learning-harmonizer/scripts/supersession_harmonizer.py union-jules \
  --target-file .jules/bolt.md \
  --source-file /path/to/feature_branch_bolt.md \
  --in-place

# 3. Close the superseded PR with reference to the merged primary PR
python .agents/skills/bot-pr-supersession-and-learning-harmonizer/scripts/supersession_harmonizer.py close-superseded \
  --pr 142 \
  --primary-pr 143
```

---

## Utility Scripts

The CLI script `supersession_harmonizer.py` provides:

### 1. `detect-duplicates`
Scans open PRs in a repository or account, compares modified file paths and titles, and ranks primary vs. superseded candidates.

```bash
python .agents/skills/bot-pr-supersession-and-learning-harmonizer/scripts/supersession_harmonizer.py detect-duplicates \
  --repo bjohnson1279/bash_encoding
```

### 2. `union-jules`
Parses all `## YYYY-MM-DD - ...` sections from both the target base file and candidate branches, merging them into a single, deduplicated, chronologically ordered markdown document.

```bash
python .agents/skills/bot-pr-supersession-and-learning-harmonizer/scripts/supersession_harmonizer.py union-jules \
  --target-file .jules/bolt.md \
  --source-file branch_bolt.md \
  --in-place
```

### 3. `close-superseded`
Executes `gh pr close` with an automated message referencing the winning PR and automatically cleans up the remote branch.

```bash
# Dry run preview:
python .agents/skills/bot-pr-supersession-and-learning-harmonizer/scripts/supersession_harmonizer.py close-superseded \
  --pr 142 \
  --primary-pr 143 \
  --dry-run

# Execute closure:
python .agents/skills/bot-pr-supersession-and-learning-harmonizer/scripts/supersession_harmonizer.py close-superseded \
  --pr 142 \
  --primary-pr 143
```

---

## Workflow

1. **Audit Open PRs**: Run `detect-duplicates` to identify overlapping candidate PRs.
2. **Evaluate Specificity & Tests**: Run test harnesses across candidates to select the winning implementation.
3. **Reconcile Documentation**: Run `union-jules` to append learnings from all candidates to `.jules/<bot>.md`.
4. **Merge Primary Candidate**: Merge the winning PR into the default branch.
5. **Close Superseded PRs**: Run `close-superseded` for remaining candidate PRs to maintain repository hygiene.

---

## Common Mistakes

1. **Closing duplicate PRs without preserving learning notes**: Bot learning notes contain critical post-mortem insights and execution profiling data. Always union `.jules/` entries before closing.
2. **Merging without verifying specificity**: When bots submit similar optimizations (e.g. `*"prefix="*` vs `*prefix=\"*`), verify test boundaries and pattern exactness.
3. **Leaving orphaned feature branches**: Always pass `--delete-branch` when closing superseded PRs to prevent remote repository clutter.
