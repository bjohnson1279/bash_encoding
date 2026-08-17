---
name: git-local-merge-harmonizer
description: >-
  Audits, diagnoses, and harmonizes local git merge conflicts occurring after
  git pull or branch merges, applying additive log reconciliation, configuration
  resets, dynamic dependency extractions, and cumulative test suite merges.
---

# Git Local Merge Harmonizer

## Overview

When developers or background agents execute `git pull origin master` (or merge diverged branches locally), conflicting changes frequently emerge across configuration files, lockfiles, memory logs, and test suites.

This skill provides a standardized, battle-tested protocol to categorize, resolve, verify, and cleanly conclude local merge conflicts without regressions or data loss.

---

## Conflict Resolution Matrix

| Conflict Category | Target Files | Resolution Strategy |
| :--- | :--- | :--- |
| **Lockfiles & Packages** | `pnpm-lock.yaml`, `package.json`, `composer.lock`, `mix.lock` | Force-checkout clean upstream version (`git checkout origin/master -- <file>`) |
| **Agent Memory Logs** | `.jules/*.md`, `.Jules/*.md` | **Additive union**: preserve upstream log entries and append local timestamped sections |
| **Isolated Shell Tests** | `test_*.sh`, `test-*.sh`, `*.bats` | Harmonize `sed -n` extractions into sequential multi-patterns in declaration order using `bash-isolated-test-harmonizer` |
| **Cumulative Test Suites** | `*test*.exs`, `*.test.ts`, `*Test.php` | **Cumulative union**: Retain both old and new test cases / assertions |
| **Database DDLs** | `docker/postgres/init/*.sql`, `migrations/` | Reset or union DDL changes ensuring idempotency (`CREATE TABLE IF NOT EXISTS`) |

---

## Workflow

### 1. Triage Unmerged Paths
Identify all conflicting files in the working tree:
```bash
git status --short | grep "^UU\|^AA\|^DU\|^UD"
```

### 2. Categorize and Apply Targeted Resolutions

#### A. Lockfiles & Static Configurations
If lockfiles or package manifests conflict:
```bash
git checkout origin/master -- pnpm-lock.yaml package.json composer.lock mix.lock
```

#### B. Agent Learning Logs (`.jules/*.md`)
Preserve all historical entries from both branches:
1. Retain upstream entries.
2. Append feature branch entries (`## YYYY-MM-DD - ...`).
3. Remove conflict markers (`<<<<<<<`, `=======`, `>>>>>>>`).
4. Stage resolved log files: `git add .jules/*.md`

#### C. Isolated Shell Test Functions (`test_*.sh`, `*.bats`)
When functions like `parseFilename` or helper subroutines are extracted using `sed -n`:
1. Use a single multi-pattern `sed -n` extraction:
   ```bash
   sed -n '/^helper_one() {/,/^}/p; /^helper_two() {/,/^}/p; /^main_func() {/,/^}/p' "$SCRIPT_DIR/script.sh" > "$TMP_FILE"
   ```
2. Run automated dynamic dependency auditing:
   ```bash
   python .agents/skills/bash-isolated-test-harmonizer/scripts/test_harmonizer.py audit --test-dir . --output audit_report.json
   ```

#### D. Cumulative Test Assertions
When branches introduce different assertions for the same function (e.g. structured JSON validation vs. raw flag `--no-json` variables):
- Keep **both** assertions in the test suite to ensure dual compatibility and zero regression.

---

### 3. Pre-Commit Verification
Execute repo-specific verification to guarantee the tree compiles and all test suites pass:
```bash
# For Bash / Shell test suites:
python .agents/skills/bash-isolated-test-harmonizer/scripts/test_harmonizer.py verify --test-dir . --output test_results.json

# For Node / TypeScript repositories:
pnpm test

# For Elixir / Phoenix repositories:
mix precommit

# For PHP repositories:
./vendor/bin/phpunit
```

---

### 4. Stage and Conclude Merge Commit
Once verification passes:
```bash
# Stage resolved files
git add <resolved_files>

# Conclude merge commit
git commit --no-edit

# Verify clean tree
git status
```

---

## Common Mistakes

1. **Choosing one branch's tests over another**: Discarding either local or upstream test assertions drops test coverage. Always use cumulative merging.
2. **Discarding agent logs**: Overwriting `.jules/*.md` wipes out valuable agent learnings and prevention notes. Always union timestamped sections.
3. **Committing without pre-commit verification**: Committing broken syntax or incomplete function dependencies breaks CI builds. Always run verification scripts before finalizing the merge.
