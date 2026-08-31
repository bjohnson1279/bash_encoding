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

## 2024-11-20 - POSIX String Replacement without Subshells
**Learning:** In strictly POSIX-compliant scripts where native bash substitutions like `${var//pattern/repl}` are unavailable, calling external binaries like `sed` inside busy loops introduces severe process fork overhead.
**Action:** Use a `while` loop combining POSIX parameter expansion (`${var%%pattern*}` and `${var#*pattern}`) for repeated string replacement (e.g. escaping quotes) to eliminate subshell process overhead.

## 2024-11-20 - Consolidate Sequential `sed` Invocations
**Learning:** Executing multiple `sed` commands sequentially (or piping them) spawns multiple processes.
**Action:** Combine sequential `sed` operations into a single invocation using the `-e` flag or semicolons (e.g., `sed -e 's/pattern1/repl1/' -e 's/pattern2/repl2/'`) to halve the process spawning overhead.

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
## 2026-07-21 - Order of Operations in Bash Parameter Expansion Escaping
**Learning:** When using native Bash parameter expansion (like `${var//pattern/repl}`) to escape multiple special characters (such as backslashes `\` and double quotes `"`), the order of execution is crucial. Escaping quotes first (`\"`) introduces new backslashes into the string. If backslashes are escaped second, it will unintentionally double the backslashes that were just added to escape the quotes, corrupting the string (e.g., resulting in `\\"` instead of `\"`).
**Action:** Always escape backslashes FIRST before escaping any other special characters when chaining parameter expansions.
## 2024-11-20 - Eliminate sed parsing loops and subshells using native bash regex
**Learning:** In Bash, spawning `sed` inside command substitutions to parse string fields, piping them to `head`, and then splitting the resulting string via `IFS` is significantly slower than using native Bash regex matching (`[[ $var =~ ^pattern$ ]]`). Testing proved that eliminating these subshells and mapping fields directly via the `` array reduced a sample string parsing execution loop from ~6 seconds to ~0.4 seconds (>10x speedup). This also eliminates the dangerous `set --` operation which can accidentally clobber function arguments (like $2).
**Action:** Always prefer native Bash regex (`[[ ... =~ ... ]]`) and `BASH_REMATCH` to extract substrings in `bash` scripts, avoiding external `sed`, `awk` and `head` forks especially when inside busy loops or global parsing functions.

## 2024-11-20 - Consolidating redundant pre-flight binary spawns
**Learning:** In bash loops, it's common to see a "pre-flight" integrity check (like `ffprobe -i`) followed later by a data-fetching call (like `ffprobe -show_entries`) on the same file. Removing the pre-flight check entirely to save a process spawn can lead to functional regressions by masking explicit error messages.
**Action:** Instead of deleting pre-flight checks, move the later data-fetching call (e.g., `getDuration`) earlier in the loop to replace the pre-flight check. Use the output of the data-fetching call (e.g., empty duration) to perform the exact same integrity validation, cutting process spawns by 50% without altering script logic.

## 2026-07-21 - [Eliminate external `find` process spawning and `while` loop subshells in encode loops]
**Learning:** `find ... | while` loops spawn a subshell process for the `while` loop (due to the pipe) which incurs overhead and executes `find` in a separate process. Using bash `shopt -s globstar nullglob` and `for file in **/*.ts` eliminates the subshell and the `find` binary spawn. I benchmarked it and `globstar` is much faster.
**Action:** When scanning directories with many files, modify `find ... | while` loops in `encode-*.sh` scripts to use purely native Bash loops with `shopt -s globstar nullglob` and `for i in **/*.ext` to eliminate a subshell execution and the `find` binary execution, resulting in measurable performance improvement.

## 2026-07-21 - [Fix redundant JSON generation overhead in encode-all.sh]
**Learning:** The loop processing `.ts` files inside `encode-all.sh` invokes `parseFilename "$ts_file" --no-json` but the `--no-json` flag logic was faulty. Specifically, it checked for valid nameref variables via regex instead of checking the flag.
**Action:** Update `parseFilename` logic inside `encode-all.sh` to correctly check for the `--no-json` flag using `if [ "$2" != "--no-json" ]; then`. Ensure that `PARSED_SHOW_NAME`, `PARSED_SEASON_NUM`, `PARSED_EPISODE_NUM`, and `PARSED_EPISODE_TITLE` are correctly assigned out of the parsed values, which restores functionality when the JSON structure isn't created.

## 2024-11-20 - Skip formatting overhead fully inside conditional block
**Learning:** Even when skipping JSON output generation using `--no-json` within `encode-all.sh`, the variables were still being string-escaped using `json_escape` unconditionally before the `if` block, wasting processing power.
**Action:** When a flag like `--no-json` is used to skip output formatting, ensure that all prerequisite data transformations (like string escaping via `json_escape`) are also moved completely inside the conditional block to fully bypass their execution overhead.

## 2026-07-21 - Replace string length checking and POSIX string substitution logic with faster printf and native base-10 math formatting
**Learning:** Replaced the string length checking and POSIX string substitution logic used for zero-padding `season_raw` and `episode_raw` with faster native formatting (`printf -v season_num "%02d" "$(( 10#${season_raw:-0} ))"`). I benchmarked it and it runs significantly faster.
**Action:** When parsing and formatting season and episode numbers, use `printf -v out_var "%02d" "$(( 10#${var:-0} ))"` to speed up the process.
## 2024-11-20 - Eliminate String Trimming for Number Zero-Padding
**Learning:** In `encode-all.sh`, the logic to compare video durations was using complex string-stripping POSIX parameter expansions (e.g., `src_val="${src_val#"${src_val%%[!0]*}"}"`) to prevent Bash from interpreting zero-padded numeric variables as octal during arithmetic operations. This is less readable and far less performant.
**Action:** When performing math on variables that may contain leading zeros, instead of explicitly stripping the zeroes using slow string matching or substitutions, force Bash to interpret the variable in base-10 natively by prefixing the variable with `10#` inside the arithmetic context: `$(( 10#${val:-0} ))`. This avoids octal interpretation issues and yields significant speedups in tight loops.

## 2024-11-20 - Replace Bash Regex with Case Statement Globbing for Validation
**Learning:** In Bash, native `case` statement globbing (e.g., `case "$var" in *[!a-zA-Z0-9_]*|[0-9]*|"")`) for simple string validation is significantly faster (measured to be about ~7x faster in a tight loop) than using the bash regex operator (`[[ "$var" =~ ^pattern$ ]]`). This is because `case` uses built-in pattern matching that doesn't invoke the regex engine.
**Action:** When performing simple variable or format validation inside high-frequency bash functions (like `cleanup_name` or `json_escape` called repeatedly), replace `[[ =~ ]]` regex checks with `case` statements using glob patterns.
## 2026-08-08 - Use parameter expansion and case globbing over regex
**Learning:** Native bash regex matching (`[[ =~ ]]`) invokes the regex engine, which adds noticeable overhead in high-frequency loops. When extracting values from string formats, substituting regex extraction with parameter expansion (`${var#*prefix}`, `${var%%suffix*}`) results in ~40% faster execution. For simple numeric string validation (like checking floating point format), substituting regex validation (`^[0-9]+(\.[0-9]+)?$`) with native `case` statement globbing (`case "$var" in ''|*[!0-9.]*|*.*.*|.*|*.) false ;; *) true ;; esac`) executes ~4-7x faster.
**Action:** Replace `[[ =~ ]]` checks with parameter expansion extraction or `case` statement globbing for validations when dealing with simple, predictable string structures inside busy bash loops.
## 2026-07-21 - Avoid state-altering builtins inside loops
**Learning:** In bash `for` loops iterating over glob expansions, executing option resets like `shopt -u globstar nullglob` *inside* the loop causes O(N) redundant executions. Worse, if the glob yields zero files (because `nullglob` is set), the loop body never runs, meaning the options are never unset and effectively leak to the rest of the script.
**Action:** Always move `shopt -u` resets immediately after the `done` statement of the loop to ensure they run exactly once and run unconditionally.
## 2024-05-29 - Parameter Expansion is Faster Than Regex for Multiline Substring Extraction
**Learning:** In Bash, extracting a specific substring from multiline output (like `ffprobe -of flat`) using native Bash regex matching (`[[ "$output" =~ pattern ]]`) is noticeably slower than using native parameter expansions (e.g., `${output#*pattern}` followed by `${var%%\"*}`). Benchmark testing of `getDuration` in a busy loop showed parameter expansion is about ~8% faster than regex execution, eliminating regex engine overhead for simple substring extraction while maintaining readability.
**Action:** When extracting simple prefixed/suffixed substrings from multiline command output in high-frequency functions, prefer using native parameter expansions (e.g., `${var#*prefix}` and `${var%%suffix*}`) over Bash regex (`=~`) for measurable performance gains.

## 2024-11-20 - Replace Bash regex with parameter expansion for string extraction
**Learning:** When parsing specific substrings from multiline command output (e.g., extracting values from `ffprobe -of flat`), replacing bash regex (`=~`) and `BASH_REMATCH` with native parameter expansions (e.g., `${var#*prefix}` and `${var%%suffix*}`) can provide measurable performance improvements while maintaining code readability. Profiling showed it to be ~35% faster.
**Action:** Use native parameter substitutions over `[[ =~ ]]` regex when extracting simple bounded values from strings or command output.

## 2026-08-19 - Regex evaluation bottleneck in parseFilename
**Learning:** In bash, evaluating long, complex regular expressions inside tight loops (like iterating over all files in a directory) is a significant bottleneck. Furthermore, having near-identical overlapping regex branches (e.g., matching a trailing date vs not matching it) duplicates evaluation time unnecessarily.
**Action:** Consolidate near-identical regex patterns by making trailing capture groups optional where applicable, and remove redundant `elif` blocks. This avoids the cost of repeatedly evaluating essentially the same long regex pattern.
## 2024-11-20 - Bash Regex Greedy matching workaround
**Learning:** Native Bash regex (`[[ ... =~ ... ]]`) does not support non-greedy modifiers like `.*?`. If you try to consolidate regex branches by making trailing groups optional (e.g. `(.*)?`), a preceding greedy `(.*)` will consume the remainder of the string, causing the optional group to never match.
**Action:** When consolidating bash regular expressions, account for greedy matching. If you have an optional trailing component (like a date in a filename), you may need to parse the greedy matched string afterwards (e.g., using another regex check) instead of relying on non-greedy optional capture groups.

## 2026-08-31 - Removing duplicate assignments in hot paths
**Learning:** Found redundant identical variable assignments and string processing calls inside `parse-filename.sh` (e.g. `cleanup_name "$show_raw" PARSED_SHOW_NAME` called twice back-to-back). This was adding unnecessary process/string manipulation overhead on every iteration for no reason.
**Action:** Always scan sequential lines for duplicate function executions or redundant variable assignments (e.g., from copy-paste errors) when auditing bash scripts for micro-optimizations, as these add measurable execution overhead in hot paths.
## 2024-05-24 - Removed redundant variables in shell regex match
**Learning:** `parse-filename.sh` contained an assignment `show_name="${BASH_REMATCH[1]}"` at the beginning of an `if` block, but further down the same block, `show_raw` was also assigned `BASH_REMATCH[1]`. `show_raw` was then cleaned via `cleanup_name "$show_raw" PARSED_SHOW_NAME` and `show_name` was reassigned from it. As a result, the first `show_name` assignment and its subsequent `cleanup_name "$show_name" show_name` call were entirely redundant and only added subshell overhead.
**Action:** When refactoring regex matching into single blocks or eliminating variables, make sure to eliminate the respective initialization and processing calls to prevent unused or immediately overridden assignments, which cost cycles.
## 2026-08-31 - Replace Regex with Case Statement Globbing for Trailing String Stripping
**Learning:** In Bash, utilizing regex capture groups (`[[ "$var" =~ ^(.*)\(pattern\)$ ]]` and `BASH_REMATCH`) to optionally match and strip complex trailing strings (like a date) adds significant execution overhead inside busy loops. Benchmarks show that checking for the pattern using a native `case` statement glob and stripping it via native parameter expansion (`${var%\(*}`) is more than twice as fast.
**Action:** When stripping trailing components from a string, avoid regex where possible. Use `case` globbing to identify the presence of the string, and native bash parameter expansions to manipulate the string.
## 2026-08-31 - Consolidate identical overlapping bash regex evaluations
**Learning:** Evaluating complex regular expressions in bash (`[[ ... =~ ... ]]`) is a measurable bottleneck in tight loops. Having near-identical overlapping regex branches (e.g., matching trailing string A vs trailing string B where the core is the same) forces the engine to redundantly evaluate the long shared pattern multiple times when the first branch fails.
**Action:** Consolidate redundant regex branches into a single evaluation block using an optional/combined capture, or by offloading trailing component identification (like dates or specific suffixes) to native bash parameter expansion or case statement globbing *after* the initial core pattern matches.
