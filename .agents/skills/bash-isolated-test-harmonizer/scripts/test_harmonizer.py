#!/usr/bin/env python3
"""
Bash Isolated Test Harmonizer CLI
Audits, fixes, and verifies isolated Bash function extractions (sed -n / process substitution)
in test harnesses using Dynamic Dependency Detection.
"""

import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional, Set, Tuple


def find_function_definitions(script_content: str) -> Dict[str, Tuple[int, int, str]]:
    """
    Parses a Bash script and returns a dictionary of:
    function_name -> (start_char, end_char, function_body_content)
    """
    funcs = {}
    lines = script_content.splitlines(keepends=True)
    in_func = False
    current_func_name = ""
    func_lines = []
    brace_depth = 0

    func_header_regex = re.compile(r"^\s*(?:function\s+)?([a-zA-Z_][a-zA-Z0-9_]*)\s*\(\s*\)\s*\{?")

    for line in lines:
        if not in_func:
            match = func_header_regex.match(line)
            if match:
                current_func_name = match.group(1)
                in_func = True
                func_lines = [line]
                brace_depth = line.count("{") - line.count("}")
                if "{" in line and brace_depth == 0:
                    # Single line function
                    funcs[current_func_name] = "".join(func_lines)
                    in_func = False
                    current_func_name = ""
                    func_lines = []
        else:
            func_lines.append(line)
            brace_depth += line.count("{") - line.count("}")
            if brace_depth <= 0:
                funcs[current_func_name] = "".join(func_lines)
                in_func = False
                current_func_name = ""
                func_lines = []

    return funcs


def get_dependencies_for_function(func_name: str, all_funcs: Dict[str, str]) -> List[str]:
    """
    Performs Dynamic Dependency Detection (DDD) by scanning the function body
    for calls to other functions declared in the same script.
    Returns dependencies in topological / declaration order.
    """
    if func_name not in all_funcs:
        return []

    visited = set()
    dependencies = []

    def dfs(current: str):
        body = all_funcs.get(current, "")
        for other_name in all_funcs:
            if other_name == current or other_name in visited:
                continue
            # Match function call as an isolated token or in command position
            pattern = rf"(?:^|[\s;|&`$(])\b{re.escape(other_name)}\b"
            if re.search(pattern, body):
                visited.add(other_name)
                dfs(other_name)
                dependencies.append(other_name)

    dfs(func_name)
    # Return unique dependencies + the target function itself
    ordered = []
    for f in all_funcs:
        if f in dependencies and f not in ordered:
            ordered.append(f)
    if func_name not in ordered:
        ordered.append(func_name)
    return ordered


def find_extraction_blocks(content: str, test_file_path: Path, base_path: Path) -> List[Dict]:
    """
    Finds both single-line sed extractions and multi-line split sed extractions (sed > followed by sed >>).
    """
    blocks = []
    handled_spans = []

    # 1. Multi-line sequential split blocks: sed > target followed by one or more sed >> target
    multi_line_regex = re.compile(
        r"(^[ \t]*sed\s+-n\s+(['\"])(.*?)\2\s+([\"']?(?:\$SCRIPT_DIR/|\./)?([a-zA-Z0-9_\-./]+\.sh)[\"']?)\s*>\s*([^\r\n]+)\r?\n"
        r"(?:[ \t]*sed\s+-n\s+(['\"])(.*?)\7\s+[\"']?(?:\$SCRIPT_DIR/|\./)?\5[\"']?\s*>>\s*\6(?:\r?\n|$))+)",
        re.MULTILINE
    )

    for match in multi_line_regex.finditer(content):
        full_block = match.group(1)
        script_ref = match.group(5).strip("\"'")
        script_arg = match.group(4)
        target_dest = match.group(6).strip()

        # Extract all functions from all sed commands in the block
        funcs = re.findall(r"/\^([a-zA-Z0-9_]+)\(\)\s*\{/", full_block)
        if funcs:
            blocks.append({
                "type": "multi_line",
                "full_match": full_block,
                "script_ref": script_ref,
                "script_arg": script_arg,
                "target_dest": target_dest,
                "extracted_functions": funcs,
                "span": match.span(),
            })
            handled_spans.append(match.span())

    # 2. Single-line extractions (including process substitutions and standalone commands)
    single_line_regex = re.compile(
        r"(sed\s+-n\s+(['\"])(.*?)\2\s+([\"']?(?:\$SCRIPT_DIR/|\./)?([a-zA-Z0-9_\-./]+\.sh)[\"']?))"
    )

    for match in single_line_regex.finditer(content):
        m_start, m_end = match.span()
        # Skip if part of an already handled multi-line block
        if any(h_start <= m_start and m_end <= h_end for h_start, h_end in handled_spans):
            continue

        full_match = match.group(1)
        sed_pattern = match.group(3)
        script_arg = match.group(4)
        script_ref = match.group(5).strip("\"'")

        funcs = re.findall(r"/\^([a-zA-Z0-9_]+)\(\)\s*\{/", sed_pattern)
        if funcs:
            blocks.append({
                "type": "single_line",
                "full_match": full_match,
                "script_ref": script_ref,
                "script_arg": script_arg,
                "target_dest": None,
                "extracted_functions": funcs,
                "span": match.span(),
            })

    return blocks


def audit_test_files(test_dir: str) -> List[Dict]:
    """
    Scans test files in test_dir for sed-based function extractions and detects missing dependencies.
    """
    results = []
    base_path = Path(test_dir).resolve()

    # Find test files
    test_files = list(base_path.glob("test*.sh")) + list(base_path.glob("parse-filename-test*.sh")) + list(base_path.glob("*.bats"))
    test_files += list((base_path / "tests").glob("**/*.sh")) if (base_path / "tests").is_dir() else []

    for tf in sorted(set(test_files)):
        if not tf.is_file():
            continue
        try:
            content = tf.read_text(encoding="utf-8", errors="ignore")
        except Exception:
            continue

        blocks = find_extraction_blocks(content, tf, base_path)
        for blk in blocks:
            script_ref = blk["script_ref"]
            script_path = (tf.parent / script_ref).resolve()
            if not script_path.is_file():
                script_path = (base_path / script_ref).resolve()
            if not script_path.is_file():
                continue

            try:
                script_content = script_path.read_text(encoding="utf-8", errors="ignore")
            except Exception:
                continue

            all_funcs = find_function_definitions(script_content)
            if not all_funcs:
                continue

            extracted_funcs = blk["extracted_functions"]
            missing_deps = {}
            for ef in extracted_funcs:
                required_chain = get_dependencies_for_function(ef, all_funcs)
                missing = [dep for dep in required_chain if dep not in extracted_funcs]
                if missing:
                    missing_deps[ef] = missing

            results.append({
                "test_file": tf.as_posix(),
                "source_script": script_path.as_posix(),
                "extracted_functions": extracted_funcs,
                "missing_dependencies": missing_deps,
                "full_command": blk["full_match"],
                "block_type": blk["type"],
                "target_dest": blk.get("target_dest"),
                "script_arg": blk.get("script_arg"),
                "is_healthy": len(missing_deps) == 0 and blk["type"] == "single_line",
            })

    return results


def fix_test_files(test_dir: str, target_file: str = None, dry_run: bool = False) -> Dict:
    """
    Rewrites incomplete and split sed extraction commands in test files to include all prerequisite helper functions.
    """
    audit_data = audit_test_files(test_dir)
    fixed_files = []

    for item in audit_data:
        if item["is_healthy"]:
            continue
        tf_path = Path(item["test_file"])
        if target_file and Path(target_file).resolve() != tf_path.resolve():
            continue

        script_content = Path(item["source_script"]).read_text(encoding="utf-8", errors="ignore")
        all_funcs = find_function_definitions(script_content)

        # Build complete required set of functions
        needed_funcs = set()
        for ef in item["extracted_functions"]:
            for dep in get_dependencies_for_function(ef, all_funcs):
                needed_funcs.add(dep)

        # Preserve declaration order from source script
        ordered_needed = [f for f in all_funcs if f in needed_funcs]

        # Construct new sed expression
        new_sed_chunks = [f"/^{f}() {{/,/^}}/p" for f in ordered_needed]
        new_sed_expr = "; ".join(new_sed_chunks)

        old_cmd = item["full_command"]
        script_arg = item.get("script_arg", "encode-all.sh")

        if item["block_type"] == "multi_line":
            target_dest = item.get("target_dest", "$TMP_FILE")
            # Determine leading indentation
            leading_ws = ""
            m_ws = re.match(r"^([ \t]*)", old_cmd)
            if m_ws:
                leading_ws = m_ws.group(1)
            new_cmd = f"{leading_ws}sed -n '{new_sed_expr}' {script_arg} > {target_dest}"
            if old_cmd.endswith("\n") and not new_cmd.endswith("\n"):
                new_cmd += "\n"
        else:
            quote_char = "'" if "'" in old_cmd else '"'
            new_cmd = re.sub(
                r"sed\s+-n\s+['\"][^'\"]+['\"]",
                f"sed -n {quote_char}{new_sed_expr}{quote_char}",
                old_cmd
            )

        tf_content = tf_path.read_text(encoding="utf-8", errors="ignore")
        updated_content = tf_content.replace(old_cmd, new_cmd)

        if updated_content != tf_content:
            if not dry_run:
                tf_path.write_text(updated_content, encoding="utf-8")
            fixed_files.append({
                "test_file": tf_path.as_posix(),
                "old_command": old_cmd,
                "new_command": new_cmd,
                "added_dependencies": [f for f in ordered_needed if f not in item["extracted_functions"]],
            })

    return {
        "status": "success",
        "dry_run": dry_run,
        "fixed_count": len(fixed_files),
        "fixes": fixed_files,
    }


def detect_test_runner() -> Dict[str, Any]:
    """Detects available test runners in the current environment."""
    runners = {"bash": False, "bash_cmd": None, "bats": False, "wsl": False}
    
    # Check for Git Bash / native Bash on Windows
    candidate_bash_paths = [
        "C:\\Program Files\\Git\\bin\\bash.exe",
        "C:\\Program Files\\Git\\usr\\bin\\bash.exe",
        "C:\\Program Files (x86)\\Git\\bin\\bash.exe",
        "bash",
    ]
    for b in candidate_bash_paths:
        try:
            res = subprocess.run([b, "--version"], capture_output=True, text=True, timeout=5)
            if res.returncode == 0 or "version" in (res.stdout + res.stderr).lower():
                runners["bash"] = True
                runners["bash_cmd"] = b
                break
        except Exception:
            continue

    for r in ["bats", "wsl"]:
        try:
            res = subprocess.run([r, "--version"], capture_output=True, text=True, timeout=5)
            if res.returncode == 0 or "version" in (res.stdout + res.stderr).lower():
                runners[r] = True
        except Exception:
            runners[r] = False

    return runners


def verify_test_suites(test_dir: str) -> Dict:
    """
    Runs executable bash and bats test suites with graceful runner fallbacks.
    """
    base_path = Path(test_dir).resolve()
    runners = detect_test_runner()
    
    test_scripts = [
        "test_parse_filename.sh",
        "test_parse_filename_encode_all.sh",
        "test_parse_filename_debug.sh",
        "test_loop_logic.sh",
    ]

    results = []
    all_passed = True

    # Run bash test scripts
    bash_exec = runners.get("bash_cmd")
    if not bash_exec and runners.get("wsl"):
        bash_exec = "wsl"

    if bash_exec:
        for ts in test_scripts:
            script_path = base_path / ts
            if not script_path.is_file():
                continue

            try:
                cmd = [bash_exec, f"./{ts}"] if bash_exec != "wsl" else ["wsl", "bash", f"./{ts}"]
                proc = subprocess.run(
                    cmd,
                    cwd=str(base_path),
                    capture_output=True,
                    text=True,
                    encoding="utf-8",
                    errors="replace",
                    timeout=60,
                )
                passed = proc.returncode == 0
                if not passed:
                    all_passed = False

                results.append({
                    "runner": "bash",
                    "script": ts,
                    "passed": passed,
                    "returncode": proc.returncode,
                    "stdout": proc.stdout[-500:] if proc.stdout else "",
                    "stderr": proc.stderr[-500:] if proc.stderr else "",
                })
            except subprocess.TimeoutExpired:
                all_passed = False
                results.append({
                    "runner": "bash",
                    "script": ts,
                    "passed": False,
                    "returncode": -1,
                    "error": "Execution timed out (30s limit)",
                })


    # Run bats tests if bats is available
    if runners["bats"]:
        bats_files = list(base_path.glob("*.bats"))
        for bf in bats_files:
            try:
                proc = subprocess.run(
                    ["bats", bf.name],
                    cwd=str(base_path),
                    capture_output=True,
                    text=True,
                    timeout=30,
                )
                passed = proc.returncode == 0
                if not passed:
                    all_passed = False
                results.append({
                    "runner": "bats",
                    "script": bf.name,
                    "passed": passed,
                    "returncode": proc.returncode,
                    "stdout": proc.stdout[-500:] if proc.stdout else "",
                    "stderr": proc.stderr[-500:] if proc.stderr else "",
                })
            except Exception as e:
                results.append({
                    "runner": "bats",
                    "script": bf.name,
                    "passed": False,
                    "returncode": -1,
                    "error": str(e),
                })

    return {
        "overall_status": "PASS" if all_passed and results else ("FAIL" if not all_passed else "NO_TESTS"),
        "runners_available": runners,
        "total_executed": len(results),
        "passed_count": sum(1 for r in results if r["passed"]),
        "failed_count": sum(1 for r in results if not r["passed"]),
        "results": results,
    }


def output_json_report(data: any, output_path: Optional[str] = None):
    """Writes JSON report to file if output_path is set, else prints formatted JSON to stdout."""
    if output_path:
        with open(output_path, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2)
    else:
        print(json.dumps(data, indent=2))


def main():
    parser = argparse.ArgumentParser(description="Bash Isolated Test Harmonizer CLI")
    subparsers = parser.add_subparsers(dest="command", required=True)

    # audit subcommand
    audit_parser = subparsers.add_parser("audit", help="Audit test files for missing function extraction dependencies")
    audit_parser.add_argument("--test-dir", default=".", help="Directory containing test scripts")
    audit_parser.add_argument("--output", default=None, help="Optional path to write JSON audit report")

    # fix subcommand
    fix_parser = subparsers.add_parser("fix", help="Fix missing function extraction dependencies in test files")
    fix_parser.add_argument("--test-dir", default=".", help="Directory containing test scripts")
    fix_parser.add_argument("--target-file", default=None, help="Optional specific test file to fix")
    fix_parser.add_argument("--dry-run", action="store_true", help="Preview changes without writing to disk")
    fix_parser.add_argument("--output", default=None, help="Optional path to write JSON fix report")

    # verify subcommand
    verify_parser = subparsers.add_parser("verify", help="Execute and verify test suites")
    verify_parser.add_argument("--test-dir", default=".", help="Directory containing test scripts")
    verify_parser.add_argument("--output", default=None, help="Optional path to write JSON verification report")

    args = parser.parse_args()

    if args.command == "audit":
        report = audit_test_files(args.test_dir)
        output_json_report(report, args.output)
        if args.output:
            print(f"Audit completed: {len(report)} extractions audited. Output written to {args.output}")

    elif args.command == "fix":
        report = fix_test_files(args.test_dir, target_file=args.target_file, dry_run=args.dry_run)
        output_json_report(report, args.output)
        if args.output:
            print(f"Fix completed: {report['fixed_count']} files updated. Output written to {args.output}")

    elif args.command == "verify":
        report = verify_test_suites(args.test_dir)
        output_json_report(report, args.output)
        status = report["overall_status"]
        if args.output:
            print(f"Verification completed ({status}): {report['passed_count']}/{report['total_executed']} passed. Output written to {args.output}")
        if status != "PASS":
            sys.exit(1)


if __name__ == "__main__":
    main()

