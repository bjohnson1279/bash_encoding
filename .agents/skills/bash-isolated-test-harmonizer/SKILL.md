---
name: bash-isolated-test-harmonizer
description: >-
  Audits, diagnoses, and harmonizes isolated Bash function extractions (sed -n, source <(...))
  across test harnesses, dynamically resolving prerequisite helper subroutines without
  triggering top-level script execution.
---

# Bash Isolated Test Harmonizer

## Overview
When writing unit tests for monolithic shell scripts, test runners often extract individual functions using `sed -n` or process substitution (`source <(sed -n '/^func() {/,/^}/p' script.sh)`) to prevent top-level execution side-effects (e.g. disk I/O, `ffmpeg` runs, network sync). 

When refactoring introduces helper subroutines (like `cleanup_name` or `json_escape`), isolated function extractions break with `command not found` errors. This skill provides automated auditing, dynamic dependency detection (DDD), and automated test patching to guarantee isolated execution integrity.

---

## Dependencies
- **Python 3.8+** (uses standard library `re`, `argparse`, `subprocess`, `json`)
- **Bash 4.0+** / `sed`

---

## Quick Start

```bash
# 1. Audit test files for missing dependencies in function extractions
python .agents/skills/bash-isolated-test-harmonizer/scripts/test_harmonizer.py audit \
  --test-dir . \
  --output audit_report.json

# 2. Automatically patch missing dependencies using Dynamic Dependency Detection
python .agents/skills/bash-isolated-test-harmonizer/scripts/test_harmonizer.py fix \
  --test-dir . \
  --output fix_report.json

# 3. Verify all test suites pass
python .agents/skills/bash-isolated-test-harmonizer/scripts/test_harmonizer.py verify \
  --test-dir . \
  --output test_results.json
```

---

## Utility Scripts

The CLI script `test_harmonizer.py` provides three subcommands:

### 1. `audit`
Scans `test_*.sh`, `test-*.sh`, and `*.bats` files for `sed -n` extraction commands. Parses the source script to identify internal function call graphs and detects any missing prerequisite subroutines.

```bash
python .agents/skills/bash-isolated-test-harmonizer/scripts/test_harmonizer.py audit \
  --test-dir . \
  --output audit_report.json
```

### 2. `fix`
Performs dynamic dependency detection on target functions and rewrites `sed -n` extraction patterns to include all necessary prerequisite helper functions in script declaration order.

```bash
# Preview changes without modifying files:
python .agents/skills/bash-isolated-test-harmonizer/scripts/test_harmonizer.py fix \
  --test-dir . \
  --dry-run \
  --output preview_fixes.json

# Apply fixes directly:
python .agents/skills/bash-isolated-test-harmonizer/scripts/test_harmonizer.py fix \
  --test-dir . \
  --output applied_fixes.json
```

### 3. `verify`
Executes test suites and outputs structured pass/fail metrics and logs to a JSON report.

```bash
python .agents/skills/bash-isolated-test-harmonizer/scripts/test_harmonizer.py verify \
  --test-dir . \
  --output verification_report.json
```

---

## Workflow

### 1. Identify Extraction Points
Locate where test files source individual functions from operational scripts:
```bash
# Example fragile extraction:
source <(sed -n '/^parseFilename() {/,/^}/p' encode-all.sh)
```

### 2. Trace Dependency Hierarchy
Inspect internal function invocations (e.g. `parseFilename` calling `cleanup_name` and `json_escape`).

### 3. Update Extraction Multi-Pattern
Replace single-function extractors with sequential multi-block extractions:
```bash
# Sourced in declaration order:
source <(sed -n '/^cleanup_name() {/,/^}/p; /^json_escape() {/,/^}/p; /^parseFilename() {/,/^}/p' encode-all.sh)
```

### 4. Modernize Legacy Assertions
Verify that test assertions validate cleaned, modern parsing rules (e.g. structured `.premiered` years, formatted digits) rather than obsolete bug artifacts.

---

## Common Mistakes

1. **Extracting only the target function**: Omitting helper subroutines results in silent subshell failures or `command not found` errors.
2. **Executing the main script during tests**: Sourcing the entire monolithic script instead of isolated functions triggers top-level code (e.g. recursive `find` loops, directory checks).
3. **Hardcoding brittle sed line numbers**: Using static line numbers (e.g. `sed -n '55,90p'`) breaks as soon as code above is modified. Always use regex function boundaries (`/^[a-zA-Z_0-9]+() {/,/^}/p`).
