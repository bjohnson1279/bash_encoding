## 2024-10-30 - Bash Built-in Parameter Expansion vs. External Process Calls
**Learning:** In Bash, spawning external processes in loops (such as `sed` or `basename` inside a subshell) introduces significant overhead. Replacing `sed` calls with bash built-in parameter expansion (`${var//./ }`, extglob) significantly improves performance.
**Action:** Always prefer native Bash string manipulation (parameter expansion and extglob) over spawning external binaries (`sed`, `awk`, `basename`, `dirname`, `tr`) when working with string operations inside busy loops or frequently called functions.
Performance optimization: Using native bash regex with `[[ "$str" =~ "pattern" ]]` inside loops provides a significant speedup (e.g., ~140x) over spawning subshells for `jq` extraction.

## 2024-06-29 - Remove jq subshells for JSON construction to boost parse speed
**Learning:** Spawning external processes like `jq` inside tight loops (like iterating over media files) adds significant process overhead. While `jq` is useful for complex manipulation, using native bash `printf -v` combined with parameter expansion for simple JSON string creation dramatically cuts execution time.
**Action:** When constructing simple, flat JSON outputs in bash functions that are called frequently or inside loops, use `printf -v var '{"key":"%s"}' "${val//\"/\\\"}"` rather than `$(jq -n ...)`. Always ensure double quotes are escaped natively for safety.

## 2024-11-20 - Eliminate Subshell Process Forking Overhead in Loops
**Learning:** Spawning subshells (`$(...)`) to capture the output of bash functions inside tight loops creates a significant performance bottleneck due to process forking overhead.
**Action:** When a function needs to return a string and is called frequently in a loop, avoid subshells. Instead, pass the name of an output variable to the function and use a nameref (`local -n var="$2"`) or `printf -v "$2"` to write the result directly into the variable.
