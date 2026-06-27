## 2024-10-30 - Bash Built-in Parameter Expansion vs. External Process Calls
**Learning:** In Bash, spawning external processes in loops (such as `sed` or `basename` inside a subshell) introduces significant overhead. Replacing `sed` calls with bash built-in parameter expansion (`${var//./ }`, extglob) significantly improves performance.
**Action:** Always prefer native Bash string manipulation (parameter expansion and extglob) over spawning external binaries (`sed`, `awk`, `basename`, `dirname`, `tr`) when working with string operations inside busy loops or frequently called functions.
Performance optimization: Using native bash regex with `[[ "$str" =~ "pattern" ]]` inside loops provides a significant speedup (e.g., ~140x) over spawning subshells for `jq` extraction.
