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

## 2024-11-20 - Reducing process spawns with ffprobe flat output
**Learning:** `ffprobe` process spawning was found to be a major bottleneck. The script was spawning `ffprobe` sequentially multiple times to fallback from a format duration to a stream duration. We can fetch both durations simultaneously in one invocation using `-show_entries format=duration:stream=duration -of flat`.
**Action:** When gathering multiple metadata points from `ffprobe`, combine them into a single call and use `-of flat` alongside bash regex `[[ ... =~ ... ]]` to extract variables natively without spawning extra fallback processes.

## 2024-11-20 - Micro-optimizations vs Readability
**Learning:** Replacing clean bash `extglob` syntax (like `${var##*( )}`) with strictly POSIX-compliant nested parameter expansion (`${var#"${var%%[! ]*}"}`) is slightly faster but significantly hurts code readability for negligible real-world impact.
**Action:** Do not sacrifice code readability to apply string manipulation micro-optimizations. Focus strictly on architectural and process-level bottlenecks (like looping external binary spawns).

## 2024-11-20 - Eliminate external awk process spawning for simple parsing
**Learning:** In strictly POSIX-compliant shell scripts where native bash substitutions are unavailable, piping command outputs (like `df` or `du`) into `awk` creates significant process overhead. By piping the command output into a native shell `read` command blocks, we can extract positional columnar data entirely within the shell process. For example, `df -P | { read -r _; read -r _ _ _ avail _; echo $(( avail / 1024 )); }` runs much faster than using `awk`.
**Action:** When extracting columns or performing simple math on command output in POSIX scripts, use pipe to `{ read ...; }` and shell arithmetic expansion `$(( ... ))` rather than spawning external `awk` processes.

## 2024-11-20 - Skip Expensive Output Formatting in Tight Loops
**Learning:** In `encode-all.sh`, the script was executing `parse_filename` inside a busy loop reading thousands of files. `parse_filename` originally formatted and printed a JSON string on every invocation, but `encode-all.sh` only consumed the raw `PARSED_*` environment variables, ignoring the JSON. The unnecessary string formatting and escaping of JSON added significant overhead.
**Action:** When a bash function generates expensive formatted output (like JSON) but is called in a busy loop that only requires the raw variable values, introduce a flag (e.g., `--no-json`) to skip the expensive formatting and escaping operations.

## 2024-11-20 - Prevent `ffmpeg` from consuming stdin in `while read` loop
**Learning:** When using `ffmpeg` inside a `find ... | while read ...` loop, `ffmpeg` will consume the standard input passed into the loop if `-nostdin` is not provided. This causes the loop to terminate prematurely after processing the first item, as the stdin stream is exhausted.
**Action:** Always append the `-nostdin` flag to `ffmpeg` invocations when executed inside a piped `while read` loop to ensure it does not swallow the standard input.

## 2024-11-20 - Replace Sequential Parameter Expansion Loops with Regex matching
**Learning:** In Bash, using a fixed-iteration `for` loop (e.g., `for j in {0..9}; do str="${str//${j}E/${j} E}"; done`) to perform string manipulation introduces significant overhead in a busy script because Bash evaluates the sequence and iterates the loop logic multiple times, even if no replacements are made.
**Action:** When performing sequential, pattern-based string substitutions that can't be handled by simple parameter expansion, prefer a native `while [[ "$str" =~ (.*[0-9])E(.*) ]]; do` loop with `BASH_REMATCH`. This regex runs mostly in C, processes the string backwards safely, and entirely skips loop iterations when the pattern isn't present, leading to measurable performance gains in tight loops.

## 2024-11-20 - Unroll short string replacement loops
**Learning:** For small, fixed-bound iterations (e.g., iterating 0-9) executed frequently inside busy Bash loops, `for i in {0..9}; do ...; done` creates sequence generation and loop condition overhead. Manually unrolling the loop into 10 explicit substitution statements runs measurably faster in high-frequency bash functions than both `for` loops and equivalent global regex matching.
**Action:** When applying a fixed, small number of parameter expansions inside a busy loop, explicitly write out the substitutions rather than relying on a `for` loop to eliminate loop setup and branch overhead.

## 2024-11-20 - [Redundant JSON construction for variable passing]
**Learning:** In bash, generating a complex JSON string via `printf` and parameter substitutions just to immediately regex-parse it back into shell variables in the calling script loop is extremely slow and redundant. A significant performance bottleneck was found where `parseFilename` set global environment variables (e.g., `SHOW_NAME`) but still built a JSON string that the caller then uselessly regex-parsed.
**Action:** When a function populates global variables, pass a `--no-json` flag to skip the expensive formatting overhead in the function, and remove the redundant regex extraction in the caller's loop to use the global variables directly.
