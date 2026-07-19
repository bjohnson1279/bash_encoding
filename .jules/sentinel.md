## 2024-05-18 - [CRITICAL] Prevent Command Injection in `sed` Via Filenames
**Vulnerability:** Arbitrary Command Execution and Logic Breaking via `sed` pattern injection
**Learning:** `encode-all.sh` parsed filenames and stored parts in `$SHOW_NAME`. Later, it executed `sed "s/$SHOW_NAME//2"`. If a parsed filename contained `/`, it would cause a `sed` syntax error. More critically, if a filename contained maliciously crafted sequences like `x//2; e command_here ; s//`, it would result in arbitrary shell command execution during the encoding loop.
**Prevention:** Avoid interpolating unsanitized variables directly into `sed` execution strings. Utilize pure Bash parameter expansion (e.g., `${var#*pattern}`) as a safer alternative for targeted string replacement or sanitizing input before use.
## 2024-05-18 - [MEDIUM] Prevent Option Injection via Filenames Starting with Hyphens
**Vulnerability:** Option Injection leading to command failure or unintended behavior.
**Learning:** `encode-all.sh` used commands like `cd $dir` and `ffprobe $1`. If a filename or directory name starts with a hyphen (e.g., `-test.ts` or `-season`), commands like `cd` and `ffprobe` interpret the name as a command-line option rather than a path, leading to syntax errors or potentially dangerous unintended behavior.
**Prevention:** Always terminate command-line options before passing variable file or directory paths to bash commands. Use `--` (e.g., `cd -- "$dir"`) for built-in bash commands and standard utilities. For specific tools like `ffmpeg` or `ffprobe`, use their designated input flags (e.g., `-i "$1"`).
## 2024-05-18 - [CRITICAL] Fix insecure failure state causing data loss
**Vulnerability:** Accidental deletion of source recordings on duration retrieval failure (Fail-Open).
**Learning:** In `encode-all.sh`, the logic to delete the original recording checked if `src_duration` equals `dest_duration`. If `ffprobe` failed (e.g., corrupted file, missing utility) or returned empty, both variables became empty strings (`""`). The comparison `"" == ""` evaluates to true, resulting in the script deleting the source file despite the encoding failing or duration not matching. This is a critical fail-open vulnerability leading to data loss.
**Prevention:** Always implement fail-secure (fail-closed) behavior. Verify that necessary variables or states are non-empty and valid before executing destructive actions. When comparing variables for a security or data-retention check, ensure they are present and non-empty (e.g., `[ -n "$var" ]`) before allowing the operation.
## 2024-05-18 - [CRITICAL] Fix Fail-Open Bash Conditional (Integer Expression Expected)
**Vulnerability:** Bypass of critical constraints and logic checks when dependencies or commands fail (Fail-Open behavior).
**Learning:** `network-copy.sh` used a numerical comparison constraint `[ "$avail_mb" -lt "$required_space" ]`. When the `get_avail_mb` function failed or was absent, `avail_mb` evaluated to an empty string. In bash, this triggers an `integer expression expected` syntax error. Critically, bash treats this error state as a `false` evaluation for the `if` condition, which causes the script to completely bypass the `exit 1` block and proceed with potentially harmful operations (in this case, disk exhaustion leading to DoS).
**Prevention:** Never rely on bash arithmetic comparisons to fail securely. When performing numerical comparisons in conditionals (e.g., `-lt`, `-gt`, `-eq`), explicitly check for empty variables using short-circuit evaluation (e.g., `[ -z "$VAR" ] || [ "$VAR" -lt "$VAL" ]`) to prevent `integer expression expected` errors and force a fail-secure (fail-closed) state.

## 2024-05-18 - [CRITICAL] Prevent Option Injection in External Commands
**Vulnerability:** Option Injection (e.g. `basename`, `echo`, `du`, `rsync` treating unescaped variables as flags)
**Learning:** The codebase frequently uses variables directly in shell commands (e.g., `basename $1` or `echo $VAR`). When the variable content begins with a hyphen (e.g., `-test.mkv`), the utility will interpret it as a command-line option rather than a positional argument, leading to unexpected behavior, command failure, or data loss.
**Prevention:** Use `--` to terminate option parsing for utilities that support it (e.g., `basename -- $1`, `du -sk -- $1`, `rsync -- $SRC $DST`). For built-ins like `echo` that lack robust POSIX `--` support, replace `echo` with `printf '%s\n' $VAR` to safely handle any input string.
## 2024-07-04 - Fix Option Injection in echo
**Vulnerability:** Widespread use of `echo "$var"` when printing untrusted user input, such as filenames (`$new_filename`, `$i`), directory paths (`$dir`), and externally fetched string content (`$json_str`).
**Learning:** In Bash, variables parsed via `echo "$var"` are susceptible to option injection if the content starts with hyphens (e.g., `-n`, `-e`). For instance, a malicious or poorly formatted filename like `-e malicious_content` can manipulate `echo`'s behavior unexpectedly.
**Prevention:** Always use `printf '%s\n' "$var"` instead of `echo "$var"` to safely output variable contents, as `printf` is not vulnerable to option injection and explicitly treats the subsequent argument as literal string data.

## 2024-05-18 - [CRITICAL] Prevent Fail-Open Directory Traversal
**Vulnerability:** Arbitrary file operation (e.g. deletion) due to unhandled `cd` failures (Fail-Open behavior).
**Learning:** `encode-all.sh` used commands like `cd ..` and `cd -- "$RECORDING_PATH" || continue` (outside a loop structure). If a directory change fails (due to permissions, deleted folders, or symlink issues), bash continues executing the script in the current, unintended directory. In scripts that perform destructive actions like `rm`, this can result in catastrophic arbitrary file deletion.
**Prevention:** Always check the exit status of directory changes and fail securely. Use `cd /path || exit 1` or `cd /path || return` to ensure the script aborts if the required directory state cannot be reached.
## 2024-05-20 - [HIGH] Prevent JSON Injection in Manual JSON Construction
**Vulnerability:** Arbitrary JSON Injection
**Learning:** When manually constructing JSON strings in bash using 'sed', only escaping quotes (") is insufficient. If a variable contains a backslash followed by a quote (e.g., \"), it escapes the injected quote escape, allowing an attacker to break out of the JSON string context.
**Prevention:** Always escape backslashes first (s/\\/\\\\/g) before escaping quotes (s/"/\\"/g) when manually building JSON strings.
Security convention: When looping through files found by 'find', use '-print0' and pipe to 'while IFS= read -r -d \'\' var' to prevent injection or breakage from filenames containing spaces, newlines, or other special characters.
## 2024-11-20 - [CRITICAL] Prevent Privilege Escalation via rsync
**Vulnerability:** Preserving SUID/Device files from untrusted network shares
**Learning:** Using `rsync -a` (archive mode) to copy files from a network share (e.g., in `network-copy.sh`) preserves device files, special files, file ownership, and file permissions, including SUID/SGID bits. This creates a critical local privilege escalation risk if the remote share is compromised or malicious.
**Prevention:** Always use explicit, restrictive flags like `rsync -rltvzh` instead of `-a` when syncing from untrusted sources to drop dangerous properties (-D, -p, -o, -g).
## 2024-05-21 - [MEDIUM] Prevent Logic Bypass in Bash Conditionals
**Vulnerability:** Bypass of logic (fail-open or fail-closed) driven by unquoted variable expansion syntax errors.
**Learning:** `encode-all.sh` used unquoted variables within test conditionals (e.g., `if [ $DEL_ORIG == 1 ]; then` and `if [ $VF != "" ]; then`). If these variables were empty or unset, the shell threw a `unary operator expected` syntax error. Bash treats syntax errors in conditionals as a `false` evaluation, which can inadvertently bypass critical logic checks or security constraints.
**Prevention:** Always quote variables within test conditionals (e.g., `[ "$VAR" == 1 ]` or `[ -n "$VAR" ]`) to ensure safe expansion and prevent syntax-error driven logic bypassing.
## 2024-07-16 - Prevent Arithmetic Expression Injection in encode-all.sh
**Vulnerability:** Untrusted input from `ffprobe` output (e.g. `format.duration`) was extracted without strict numeric validation and then evaluated in an arithmetic context (`$(( src_val - dest_val ))`). This allows Arithmetic Expression Injection, where an attacker manipulating the video metadata can achieve arbitrary command execution.
**Learning:** In Bash, any variable expanded inside an arithmetic context (like `$(( ... ))`, `let`, or `(( ... ))`) is recursively evaluated as a mathematical expression. If an attacker controls the variable, they can inject malicious expressions. For example, if a variable contains `a[$(touch /tmp/pwn)]`, Bash will evaluate the command substitution while attempting to resolve the array index.
**Prevention:** Never use untrusted input directly in arithmetic contexts. Always validate that variables contain strictly numeric values (using a regex like `^[0-9]+(\.[0-9]+)?$`) before performing math operations on them.
## 2026-07-19 - [MEDIUM] Fix Word Splitting and Globbing vulnerabilities in ffmpeg arguments
**Vulnerability:** Unquoted variable expansion in ffmpeg invocations leading to word splitting and globbing.
**Learning:** In `encode-all.sh`, the script invoked `ffmpeg` with variables like `-vf $VF`, `-c:v $ENC_TYPE`, `-preset $PRESET`, and `-crf $QUALITY`. While currently hardcoded to safe values, if these configurations ever included spaces or wildcards (e.g., a complex filter string in `$VF`), bash would split them into multiple arguments or expand them, causing `ffmpeg` to fail or execute unintended behavior.
**Prevention:** Always enclose variable expansions in double quotes (e.g., `-vf "$VF"`) when passing them as arguments to commands to prevent word splitting and globbing vulnerabilities.
