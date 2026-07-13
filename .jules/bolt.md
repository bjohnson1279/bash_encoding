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

## 2024-10-31 - Overwriting Executable Shell Scripts
**Learning:** When completely overwriting executable shell scripts (e.g., via `cat << 'EOF' > file.sh`), the file may unexpectedly lose its executable permissions (changing from `100755` to `100644`). This loss of the executable bit breaks direct command-line execution and introduces blocking regressions.
**Action:** Always verify the file mode via `git diff` or `ls -l` after overwriting a script. Explicitly restore the executable bit (`chmod +x file.sh`) if it was lost during the file modification process.

## 2024-10-31 - Modifying POSIX Scripts
**Learning:** When optimizing a script explicitly marked as "POSIX-compliant" or using the `#!/usr/bin/env sh` shebang, changing the shebang to `bash` or introducing pure bashisms (like `${var//pattern/replacement}`) violates the project's architectural constraints.
**Action:** Always strictly maintain POSIX compliance for `sh` scripts. If parameter expansion is needed, utilize POSIX-compliant syntax (like `${var#"${var%%[! ]*}"}`) and avoid bash-only extensions.

## 2024-11-20 - Eliminate Subshell Process Forking Overhead in Loops (Part 2)
**Learning:** Command substitution like `var=$(printf ...)` inside tight loops spawns a subshell for each iteration, causing significant overhead.
**Action:** Use native Bash `printf -v <var>` instead of command substitution `var=$(printf ...)` for string formatting and assignment to completely eliminate subshell process creation overhead in busy loops.

## 2024-11-20 - POSIX String Splitting with IFS
**Learning:** When working in POSIX compliant shell scripts (e.g. `sh`), using `tr` combined with process substitution (like `$(printf '%s\n' "$1" | tr '._' '  ')`) adds significant overhead by creating subshells. It's much faster to use the native shell's Internal Field Separator (`IFS`) to split and parse the string without launching external commands.
**Action:** When working in strict POSIX mode where bash extensions are not available, utilize `IFS` inside the shell for string splitting to avoid slow external processes in tight loops.

## 2024-11-20 - Bash regex parsing vs sed
**Learning:** Using `sed` wrapped inside a `$(...)` command substitution spawns a subshell process for every invocation. When parsing lots of text or files in Bash, native regular expression extraction using `[[ $str =~ $regex ]]` with the `${BASH_REMATCH}` array is dramatically faster as it operates entirely within the main shell process.
**Action:** When working in a shell with `#!/usr/bin/env bash` (which implies Bash extensions are allowed), strictly prefer the native `[[ ... =~ ... ]]` operator over external matching binaries like `sed` or `grep` combined with subshells to avoid major performance overhead. Ensure spaces within character classes are escaped (`[._\ -]`) to avoid syntax errors.

## 2024-11-20 - [Avoid Expensive bc/awk Process Spawning in Tight Loops]
**Learning:** In `encode-all.sh`, the logic to compare video durations used `bc` and `bc -l` inside multiple command substitution subshells for every file processed. This process spawning is extremely expensive in bash tight loops. We found that spawning awk or bc for a simple floating-point difference (`< 1.0`) is magnitudes slower than manipulating strings and using pure integer math.
**Action:** When performing simple floating-point comparisons (e.g., `< 1.0`) in a busy loop in bash, avoid `bc` and `awk`. Instead, use pure bash fixed-point arithmetic: split the strings into integer and fractional parts, pad the fractions to a common length (e.g., 6 digits), concatenate them, strip leading zeros, and then use native bash integer subtraction `(( src_val - dest_val ))`.
