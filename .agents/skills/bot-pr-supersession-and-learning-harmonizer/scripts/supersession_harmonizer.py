#!/usr/bin/env python3
"""
Bot PR Supersession & Learning Harmonizer CLI
Audits duplicate/competing bot PRs, additively reconciles .jules/*.md learning entries,
and safely closes superseded pull requests with audit trails.
"""

import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional, Set, Tuple


def run_cmd(cmd: List[str], cwd: Optional[str] = None) -> Tuple[int, str, str]:
    try:
        proc = subprocess.run(
            cmd,
            cwd=cwd,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=60,
        )
        return proc.returncode, proc.stdout, proc.stderr
    except Exception as e:
        return 1, "", str(e)


def detect_duplicate_prs(repo: Optional[str] = None) -> Dict:
    """
    Scans open PRs in a repository for duplicate or competing bot implementations.
    """
    cmd = ["gh", "pr", "list", "--state", "open", "--json", "number,title,headRefName,baseRefName,mergeable,createdAt,body"]
    if repo:
        cmd.extend(["--repo", repo])

    code, stdout, stderr = run_cmd(cmd)
    if code != 0:
        return {"status": "error", "message": stderr}

    try:
        prs = json.loads(stdout)
    except Exception as e:
        return {"status": "error", "message": str(e)}

    pr_files = {}
    for pr in prs:
        num = pr.get("number")
        diff_cmd = ["gh", "pr", "diff", str(num), "--name-only"]
        if repo:
            diff_cmd.extend(["--repo", repo])
        d_code, d_out, _ = run_cmd(diff_cmd)
        if d_code == 0:
            files = [f.strip() for f in d_out.splitlines() if f.strip() and not f.strip().startswith(".jules/") and not f.strip().endswith(".md")]
            pr_files[num] = set(files)
        else:
            pr_files[num] = set()

    duplicate_groups = []
    handled = set()

    for i, p1 in enumerate(prs):
        n1 = p1.get("number")
        if n1 in handled:
            continue
        group = [p1]
        f1 = pr_files.get(n1, set())

        for j, p2 in enumerate(prs[i + 1:], start=i + 1):
            n2 = p2.get("number")
            if n2 in handled:
                continue
            f2 = pr_files.get(n2, set())

            has_file_overlap = bool(f1 and f2 and (f1 & f2))
            title1_words = set(p1.get("title", "").lower().split())
            title2_words = set(p2.get("title", "").lower().split())
            title_overlap = len(title1_words & title2_words) >= 4

            if has_file_overlap or title_overlap:
                group.append(p2)
                handled.add(n2)

        if len(group) > 1:
            handled.add(n1)
            # Rank candidates: newer or higher specificity
            primary = group[-1]
            superseded = group[:-1]
            duplicate_groups.append({
                "target_files": list(f1),
                "primary_candidate": primary.get("number"),
                "primary_title": primary.get("title"),
                "superseded_candidates": [s.get("number") for s in superseded],
                "prs": group,
            })

    return {
        "status": "success",
        "total_prs_audited": len(prs),
        "duplicate_groups_count": len(duplicate_groups),
        "duplicate_groups": duplicate_groups,
    }


def parse_jules_sections(content: str) -> Tuple[str, List[Dict[str, str]]]:
    """
    Parses .jules markdown content into header preamble and individual learning sections.
    """
    lines = content.splitlines(keepends=True)
    header_lines = []
    sections = []
    current_section = None

    section_header_regex = re.compile(r"^##\s+(\d{4}-\d{2}-\d{2})\s*-\s*(.+)$")

    for line in lines:
        match = section_header_regex.match(line)
        if match:
            if current_section:
                sections.append(current_section)
            current_section = {
                "date": match.group(1).strip(),
                "title": match.group(2).strip(),
                "full_header": line.strip(),
                "body_lines": [],
            }
        else:
            if current_section is None:
                header_lines.append(line)
            else:
                current_section["body_lines"].append(line)

    if current_section:
        sections.append(current_section)

    return "".join(header_lines), sections


def union_jules_files(base_file: str, feature_content: str) -> str:
    """
    Additively unions learning entries from feature branch into base_file without losing any entries.
    """
    base_path = Path(base_file)
    base_content = base_path.read_text(encoding="utf-8", errors="ignore") if base_path.is_file() else ""

    base_preamble, base_sections = parse_jules_sections(base_content)
    _, feat_sections = parse_jules_sections(feature_content)

    existing_keys = set()
    for s in base_sections:
        # Key by date + normalized title
        key = f"{s['date']}:{re.sub(r'[^a-zA-Z0-9]', '', s['title'].lower())}"
        existing_keys.add(key)

    new_sections = []
    for s in feat_sections:
        key = f"{s['date']}:{re.sub(r'[^a-zA-Z0-9]', '', s['title'].lower())}"
        if key not in existing_keys:
            new_sections.append(s)
            existing_keys.add(key)

    combined_lines = [base_preamble.rstrip("\n")]
    if combined_lines and combined_lines[0]:
        combined_lines.append("\n\n")

    for s in base_sections:
        combined_lines.append(s["full_header"] + "\n")
        combined_lines.append("".join(s["body_lines"]).rstrip("\n") + "\n\n")

    for s in new_sections:
        combined_lines.append(s["full_header"] + "\n")
        combined_lines.append("".join(s["body_lines"]).rstrip("\n") + "\n\n")

    return "".join(combined_lines).rstrip() + "\n"


def close_superseded_pr(pr_number: int, primary_pr: int, repo: Optional[str] = None, dry_run: bool = False) -> Dict:
    """
    Closes a superseded PR with a canonical reference to the primary merged PR.
    """
    comment = f"Closing as superseded: equivalent changes merged via PR #{primary_pr}."
    cmd = ["gh", "pr", "close", str(pr_number), "--comment", comment, "--delete-branch"]
    if repo:
        cmd.extend(["--repo", repo])

    if dry_run:
        return {
            "status": "dry_run",
            "pr_number": pr_number,
            "primary_pr": primary_pr,
            "comment": comment,
        }

    code, stdout, stderr = run_cmd(cmd)
    return {
        "status": "success" if code == 0 else "error",
        "pr_number": pr_number,
        "primary_pr": primary_pr,
        "stdout": stdout,
        "stderr": stderr,
    }


def output_json_report(data: any, output_path: Optional[str] = None):
    if output_path:
        with open(output_path, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2)
    else:
        print(json.dumps(data, indent=2))


def main():
    parser = argparse.ArgumentParser(description="Bot PR Supersession & Learning Harmonizer CLI")
    subparsers = parser.add_subparsers(dest="command", required=True)

    # detect-duplicates
    dup_parser = subparsers.add_parser("detect-duplicates", help="Detect duplicate and competing bot PRs")
    dup_parser.add_argument("--repo", default=None, help="Optional GitHub repository (owner/repo)")
    dup_parser.add_argument("--output", default=None, help="Optional path to write JSON report")

    # union-jules
    union_parser = subparsers.add_parser("union-jules", help="Additively union Jules learning notes across branches")
    union_parser.add_argument("--target-file", required=True, help="Path to local .jules/*.md file")
    union_parser.add_argument("--source-file", default=None, help="Path to feature branch .jules/*.md file or string")
    union_parser.add_argument("--in-place", action="store_true", help="Write unioned result directly to target-file")
    union_parser.add_argument("--output", default=None, help="Optional path to write output")

    # close-superseded
    close_parser = subparsers.add_parser("close-superseded", help="Close superseded PRs with clean audit references")
    close_parser.add_argument("--pr", type=int, required=True, help="PR number to close")
    close_parser.add_argument("--primary-pr", type=int, required=True, help="Primary PR number that was merged")
    close_parser.add_argument("--repo", default=None, help="Optional GitHub repository (owner/repo)")
    close_parser.add_argument("--dry-run", action="store_true", help="Simulate closure without mutating GitHub state")
    close_parser.add_argument("--output", default=None, help="Optional path to write JSON report")

    args = parser.parse_args()

    if args.command == "detect-duplicates":
        report = detect_duplicate_prs(repo=args.repo)
        output_json_report(report, args.output)
        if args.output:
            print(f"Duplicate audit completed: {report.get('duplicate_groups_count', 0)} duplicate group(s) found. Written to {args.output}")

    elif args.command == "union-jules":
        source_content = ""
        if args.source_file and Path(args.source_file).is_file():
            source_content = Path(args.source_file).read_text(encoding="utf-8", errors="ignore")
        unioned = union_jules_files(args.target_file, source_content)
        if args.in_place:
            Path(args.target_file).write_text(unioned, encoding="utf-8")
            print(f"Successfully unioned learning notes in-place to {args.target_file}")
        elif args.output:
            with open(args.output, "w", encoding="utf-8") as f:
                f.write(unioned)
            print(f"Unioned output written to {args.output}")
        else:
            print(unioned)

    elif args.command == "close-superseded":
        report = close_superseded_pr(pr_number=args.pr, primary_pr=args.primary_pr, repo=args.repo, dry_run=args.dry_run)
        output_json_report(report, args.output)
        if args.output:
            print(f"PR closure report written to {args.output}")


if __name__ == "__main__":
    main()
