#!/usr/bin/env python3
"""
Bot PR Triage & Batch Merge Runner CLI
Enhanced with account-wide cross-repo PR discovery and local workspace/submodule mapping.
"""

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Dict, List, Optional, Tuple


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


def discover_all_prs(owner: str, state: str = "open", limit: int = 100) -> Dict:
    """
    Discovers all open PRs across all repositories owned by the given user/org.
    Fetches mergeability status, branch details, and CI check status rollups.
    """
    cmd = [
        "gh", "search", "prs",
        "--owner", owner,
        "--state", state,
        "--limit", str(limit),
        "--json", "repository,number,title,url,createdAt,body"
    ]
    code, stdout, stderr = run_cmd(cmd)
    if code != 0:
        return {"status": "error", "message": stderr}

    try:
        prs_raw = json.loads(stdout)
    except json.JSONDecodeError:
        return {"status": "error", "message": "Failed to parse gh output"}

    detailed_prs = []
    for pr in prs_raw:
        repo_name = pr.get("repository", {}).get("nameWithOwner")
        pr_number = pr.get("number")
        if not repo_name or not pr_number:
            continue

        # Query detailed PR status
        view_cmd = [
            "gh", "pr", "view", str(pr_number),
            "--repo", repo_name,
            "--json", "number,title,state,mergeable,headRefName,baseRefName,statusCheckRollup,url"
        ]
        v_code, v_stdout, _ = run_cmd(view_cmd)
        if v_code == 0:
            try:
                v_data = json.loads(v_stdout)
                v_data["repository"] = repo_name
                detailed_prs.append(v_data)
                continue
            except json.JSONDecodeError:
                pass

        # Fallback to basic record
        detailed_prs.append({
            "number": pr_number,
            "title": pr.get("title"),
            "repository": repo_name,
            "url": pr.get("url"),
            "state": "OPEN",
            "mergeable": "UNKNOWN",
            "statusCheckRollup": []
        })

    # Group by repository
    by_repo = {}
    for pr in detailed_prs:
        repo = pr.get("repository", "unknown")
        by_repo.setdefault(repo, []).append(pr)

    return {
        "status": "success",
        "owner": owner,
        "total_prs": len(detailed_prs),
        "repositories_count": len(by_repo),
        "by_repository": by_repo,
        "prs": detailed_prs
    }


def map_workspaces(prs_file: str, dev_root: str) -> Dict:
    """
    Correlates discovered remote PR repositories with local checkout folders and submodules.
    """
    with open(prs_file, "r", encoding="utf-8") as f:
        data = json.load(f)

    prs = data.get("prs", [])
    dev_path = Path(dev_root).resolve()
    mapped = []

    # Map existing directories in dev_root
    local_repos = {}
    if dev_path.is_dir():
        for item in dev_path.iterdir():
            if item.is_dir() and (item / ".git").exists():
                r_code, r_out, _ = run_cmd(["git", "remote", "get-url", "origin"], cwd=str(item))
                if r_code == 0 and r_out.strip():
                    local_repos[r_out.strip().lower()] = str(item)

            # Check submodules inside parent repos (e.g. inventory)
            if item.is_dir() and (item / ".gitmodules").exists():
                for sub in item.iterdir():
                    if sub.is_dir() and ((sub / ".git").exists() or (sub / ".git").is_file()):
                        s_code, s_out, _ = run_cmd(["git", "remote", "get-url", "origin"], cwd=str(sub))
                        if s_code == 0 and s_out.strip():
                            local_repos[s_out.strip().lower()] = str(sub)

    for pr in prs:
        repo = pr.get("repository", "")
        matched_path = None
        for remote_url, local_dir in local_repos.items():
            if repo.lower() in remote_url:
                matched_path = local_dir
                break

        mapped.append({
            "repository": repo,
            "pr_number": pr.get("number"),
            "title": pr.get("title"),
            "mergeable": pr.get("mergeable"),
            "head_branch": pr.get("headRefName"),
            "base_branch": pr.get("baseRefName"),
            "local_path": matched_path,
            "has_local_checkout": matched_path is not None
        })

    return {
        "status": "success",
        "total_mapped": len(mapped),
        "matched_local": sum(1 for m in mapped if m["has_local_checkout"]),
        "mappings": mapped
    }


def audit_prs(input_file: str, base_dir: str = ".") -> Dict:
    """
    Audits PRs into Group A (Safe/Merge), Group A (Needs Sync), Group B (Defective), Group C (0-diff).
    """
    with open(input_file, "r", encoding="utf-8") as f:
        data = json.load(f)

    prs = data.get("prs", []) if "prs" in data else data
    group_a = []
    group_a_sync = []
    group_b = []
    group_c = []

    for pr in prs:
        mergeable = pr.get("mergeable", "UNKNOWN")
        checks = pr.get("statusCheckRollup", [])
        title = pr.get("title", "")

        has_failure = any(c.get("conclusion") in ["FAILURE", "ACTION_REQUIRED", "TIMED_OUT"] for c in checks)
        all_success = len(checks) > 0 and all(c.get("conclusion") == "SUCCESS" for c in checks)

        if mergeable == "CONFLICTING":
            group_a_sync.append(pr)
        elif has_failure:
            group_b.append(pr)
        elif all_success:
            group_a.append(pr)
        else:
            group_a.append(pr)

    return {
        "group_a_safe": group_a,
        "group_a_needs_sync": group_a_sync,
        "group_b_defective": group_b,
        "group_c_zero_diff": group_c,
    }


def main():
    parser = argparse.ArgumentParser(description="Bot PR Triage & Batch Merge Runner CLI")
    subparsers = parser.add_subparsers(dest="command", required=True)

    # discover-all
    disc_parser = subparsers.add_parser("discover-all", help="Discover all open PRs across owner account")
    disc_parser.add_argument("--owner", required=True, help="GitHub owner username / organization")
    disc_parser.add_argument("--state", default="open", help="PR state (open, closed, all)")
    disc_parser.add_argument("--limit", type=int, default=100, help="Max PRs to fetch")
    disc_parser.add_argument("--output", required=True, help="Path to write JSON discovery report")

    # map-workspaces
    map_parser = subparsers.add_parser("map-workspaces", help="Map discovered PRs to local checkouts")
    map_parser.add_argument("--prs-file", required=True, help="JSON file generated by discover-all")
    map_parser.add_argument("--dev-root", default="C:/Users/johns/DEV", help="Root directory containing local projects")
    map_parser.add_argument("--output", required=True, help="Path to write JSON mapping report")

    # audit
    audit_parser = subparsers.add_parser("audit", help="Audit PRs into triage groups")
    audit_parser.add_argument("--input-file", required=True, help="JSON input PR file")
    audit_parser.add_argument("--output", required=True, help="Path to write JSON audit report")

    args = parser.parse_args()

    if args.command == "discover-all":
        report = discover_all_prs(owner=args.owner, state=args.state, limit=args.limit)
        with open(args.output, "w", encoding="utf-8") as f:
            json.dump(report, f, indent=2)
        print(f"Discovery completed: {report.get('total_prs', 0)} PRs across {report.get('repositories_count', 0)} repositories. Written to {args.output}")

    elif args.command == "map-workspaces":
        report = map_workspaces(prs_file=args.prs_file, dev_root=args.dev_root)
        with open(args.output, "w", encoding="utf-8") as f:
            json.dump(report, f, indent=2)
        print(f"Workspace mapping completed: {report.get('matched_local', 0)}/{report.get('total_mapped', 0)} PRs matched local workspaces. Written to {args.output}")

    elif args.command == "audit":
        report = audit_prs(input_file=args.input_file)
        with open(args.output, "w", encoding="utf-8") as f:
            json.dump(report, f, indent=2)
        print(f"Triage audit completed. Output written to {args.output}")


if __name__ == "__main__":
    main()
