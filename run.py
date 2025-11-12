#!/usr/bin/env python3
"""
build-sequence.py

Purpose:
  - Walk through all version branches in a git repo (named like v2.1, v3.0, v11.0, v30.0, ...)
  - Skip blacklisted helper branches
  - Order branches numerically
  - For each branch:
      * checkout branch
      * update LABEL org.opencontainers.image.revision="manual-trigger-YYYYMMDD" in Dockerfile
      * git add/commit/push
      * poll GitHub Actions for the workflow run that corresponds to that branch until completion
      * if success -> continue to next branch; if failure -> stop and print failure info
Usage:
  ./build-sequence.py --repo /path/to/clone --owner mocacinno --repo-name bitcoin_core_docker
Requires:
  - git available in PATH
  - Python 3.8+
  - requests: pip install requests
Environment:
  - GITHUB_TOKEN (optional but recommended): token with repo/actions read/write if required.
Notes:
  - The script expects the Dockerfile path at the repo root named "Dockerfile". If it's different, change DOCKERFILE_PATH.
  - The script uses push to 'origin' remote. Adjust as needed.
"""

import argparse
import datetime
import os
import re
import subprocess
import sys
import time
from typing import List, Tuple, Optional

try:
    import requests
except Exception:
    print("Missing dependency: requests. Install with: pip install requests")
    sys.exit(1)

# -------------------------
# Configuration / defaults
# -------------------------
DOCKERFILE_PATH = "Dockerfile"   # relative to repo root
REMOTE_NAME = "origin"
POLL_INTERVAL = 60  # seconds between checks of the GitHub Actions run
GITHUB_API_BASE = "https://api.github.com"

# -------------------------
# Helpers
# -------------------------
def run_cmd(cmd: List[str], cwd: Optional[str] = None, capture_output: bool = False):
    """Run shell command; raise on non-zero exit. Returns stdout if capture_output."""
    if capture_output:
        proc = subprocess.run(cmd, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        if proc.returncode != 0:
            raise RuntimeError(f"Command {' '.join(cmd)} failed: {proc.stderr.strip()}")
        return proc.stdout.strip()
    else:
        proc = subprocess.run(cmd, cwd=cwd)
        if proc.returncode != 0:
            raise RuntimeError(f"Command {' '.join(cmd)} failed with code {proc.returncode}")
        return None

def ensure_clone(local_path: str, remote_url: str, verbose: bool):
    if os.path.isdir(local_path) and os.path.isdir(os.path.join(local_path, ".git")):
        if verbose:
            print(f"[+] Repo exists at {local_path}, fetching latest refs...")
        run_cmd(["git", "fetch", REMOTE_NAME, "--prune"], cwd=local_path)
    else:
        if verbose:
            print(f"[+] Cloning {remote_url} -> {local_path}")
        run_cmd(["git", "clone", remote_url, local_path])

def list_branches(local_path: str, verbose: bool) -> List[str]:
    """Return list of remote branches (refs/remotes/origin/branch -> branch)"""
    out = run_cmd(["git", "branch", "-r"], cwd=local_path, capture_output=True)
    branches = []
    for line in out.splitlines():
        line = line.strip()
        # skip HEAD pointer
        if "->" in line:
            continue
        # Expect origin/branch
        if line.startswith(f"{REMOTE_NAME}/"):
            branch = line[len(REMOTE_NAME)+1:]
            branches.append(branch)
    if verbose:
        print(f"[+] Found {len(branches)} remote branches")
    return sorted(set(branches))

def filter_branches(branches: List[str], blacklist: List[str], verbose: bool) -> List[str]:
    filtered = [b for b in branches if b not in blacklist]
    if verbose:
        removed = set(branches) - set(filtered)
        print(f"[+] Blacklist removed {len(removed)} branches: {sorted(list(removed))}")
    return filtered

semver_re = re.compile(r"^v([0-9]+)(?:[._]([0-9]+))?(?:[._]([0-9]+))?$")
def branch_to_sort_key(branch: str) -> Tuple:
    """
    Convert branch name like v2.1 or v11.0.1 into tuple of ints for correct numeric sorting.
    Unknown patterns will be pushed to the end by using large numbers.
    """
    m = semver_re.match(branch)
    if not m:
        # nonstandard branch -> put at end, keep ascii fallback
        return (9999, 9999, 9999, branch)
    a = int(m.group(1) or 0)
    b = int(m.group(2) or 0)
    c = int(m.group(3) or 0)
    return (a, b, c, branch)

def sort_branches(branches: List[str], verbose: bool) -> List[str]:
    sorted_br = sorted(branches, key=branch_to_sort_key)
    if verbose:
        print("[+] Sorted branches:")
        for b in sorted_br:
            print("    ", b)
    return sorted_br

def update_dockerfile_label(repo_path: str, label_date: str, verbose: bool) -> bool:
    """
    Find and replace the LABEL org.opencontainers.image.revision="manual-trigger-YYYYMMDD"
    Return True if changed, False if not.
    """
    dfpath = os.path.join(repo_path, DOCKERFILE_PATH)
    if not os.path.isfile(dfpath):
        raise FileNotFoundError(f"Dockerfile not found at {dfpath}")

    with open(dfpath, "r", encoding="utf-8") as f:
        lines = f.readlines()
    changed = False
    newlines = []
    label_pattern = re.compile(r'^(LABEL\s+org\.opencontainers\.image\.revision\s*=\s*")(manual-trigger-[0-9]{8})(".*)$')
    replaced_any = False
    for ln in lines:
        m = label_pattern.match(ln.strip())
        if m:
            prefix, old, suffix = m.group(1), m.group(2), m.group(3)
            new_label = f'{prefix}manual-trigger-{label_date}{suffix}\n'
            newlines.append(new_label)
            replaced_any = True
            changed = (old != f"manual-trigger-{label_date}")
            if verbose:
                print(f"[+] Replacing label {old} -> manual-trigger-{label_date}")
        else:
            newlines.append(ln)
    if not replaced_any:
        # If the exact label line doesn't exist, append it (helpful for older Dockerfiles)
        newline = f'LABEL org.opencontainers.image.revision="manual-trigger-{label_date}"\n'
        newlines.append("\n" + newline)
        changed = True
        if verbose:
            print("[+] Label line not found. Appending new LABEL line.")

    if changed:
        with open(dfpath, "w", encoding="utf-8") as f:
            f.writelines(newlines)
    return changed

def git_checkout_and_update(repo_path: str, branch: str, label_date: str, verbose: bool, dry_run: bool):
    # checkout branch
    if verbose:
        print(f"[+] Checking out branch {branch}")
    run_cmd(["git", "checkout", "--force", branch], cwd=repo_path)
    # ensure branch is up-to-date with remote
    run_cmd(["git", "reset", "--hard", f"{REMOTE_NAME}/{branch}"], cwd=repo_path)
    changed = update_dockerfile_label(repo_path, label_date, verbose)
    if not changed:
        if verbose:
            print("[+] Dockerfile label already up-to-date (no change).")
        return False  # no commit/push necessary

    if dry_run:
        print("[DRY-RUN] Would commit and push changes for", branch)
        return True

    # git add/commit/push
    run_cmd(["git", "add", DOCKERFILE_PATH], cwd=repo_path)
    commit_msg = f'ci: manual rebuild trigger {label_date} (automated)'
    run_cmd(["git", "commit", "-m", commit_msg], cwd=repo_path)
    run_cmd(["git", "push", REMOTE_NAME, f"{branch}"], cwd=repo_path)
    if verbose:
        print(f"[+] Pushed commit to {branch}")
    time.sleep(15)
    return True

# -------------------------
# GitHub Actions polling
# -------------------------
def get_latest_workflow_run(owner: str, repo: str, branch: str, token: Optional[str], verbose: bool):
    """
    Query GitHub Actions runs for the repo+branch and return the newest run or None.
    See: GET /repos/{owner}/{repo}/actions/runs
    """
    url = f"{GITHUB_API_BASE}/repos/{owner}/{repo}/actions/runs"
    headers = {"Accept": "application/vnd.github+json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    params = {"branch": branch, "per_page": 5}
    r = requests.get(url, headers=headers, params=params)
    if r.status_code != 200:
        if verbose:
            print(f"[!] GitHub API returned {r.status_code}: {r.text}")
        return None
    j = r.json()
    runs = j.get("workflow_runs", [])
    if not runs:
        return None
    # choose latest by created_at
    runs_sorted = sorted(runs, key=lambda x: x.get("created_at", ""), reverse=True)
    return runs_sorted[0]  # newest

def poll_workflow_until_done(owner: str, repo: str, branch: str, token: Optional[str], poll_interval: int, verbose: bool):
    """
    Poll until the latest workflow for branch completes (or detects failure).
    Returns dict of run if completed, or raises on failure/timeout.
    """
    if verbose:
        print(f"[+] Polling GitHub Actions for branch {branch} ...")
    last_seen_id = None
    while True:
        run = get_latest_workflow_run(owner, repo, branch, token, verbose)
        if run is None:
            if verbose:
                print("[...] No workflow run detected yet for branch; sleeping.")
            time.sleep(poll_interval)
            continue
        run_id = run.get("id")
        status = run.get("status")         # queued, in_progress, completed
        conclusion = run.get("conclusion") # success, failure, cancelled, timed_out, etc
        html_url = run.get("html_url")
        head_branch = run.get("head_branch")
        created_at = run.get("created_at")

        if last_seen_id != run_id:
            if verbose:
                print(f"[+] Detected run id={run_id} branch={head_branch} created_at={created_at} status={status} conclusion={conclusion} url={html_url}")
            last_seen_id = run_id

        if status in ("queued", "in_progress"):
            if verbose:
                print(f"[+] Run {run_id} status={status}. Waiting {poll_interval} sec...")
            time.sleep(poll_interval)
            continue
        elif status == "completed":
            if conclusion == "success":
                if verbose:
                    print(f"[+] Run {run_id} completed successfully: {html_url}")
                return run
            else:
                # failure/cancelled/time_out/etc -> raise to stop the sequence
                raise RuntimeError(f"Workflow run {run_id} finished with conclusion={conclusion}. See {html_url}")
        else:
            # unknown status -> wait
            if verbose:
                print(f"[+] Run {run_id} unknown status={status}, sleeping.")
            time.sleep(poll_interval)

# -------------------------
# CLI and main loop
# -------------------------
def main():
    p = argparse.ArgumentParser(description="Automate sequential rebuild triggers for branches via Dockerfile LABEL update + GitHub Actions polling.")
    p.add_argument("--repo", "-r", required=True, help="Path to local clone (will clone if missing).")
    p.add_argument("--remote-url", required=True, help="Repo remote URL (e.g. https://github.com/mocacinno/bitcoin_core_docker.git)")
    p.add_argument("--owner", required=True, help="GitHub owner/organization (e.g. mocacinno)")
    p.add_argument("--repo-name", required=True, help="GitHub repository name (e.g. bitcoin_core_docker)")
    p.add_argument("--blacklist", nargs="*", default=["main", "master", "develop", "helpers", "ci", "workflows"], help="Branches to ignore.")
    p.add_argument("--start-from", default=None, help="Start from this branch name (inclusive). Useful to resume.")
    p.add_argument("--dry-run", action="store_true", help="Don't commit/push; only show what would happen.")
    p.add_argument("--once", action="store_true", help="Do only one branch then exit (useful for debugging).")
    p.add_argument("--poll-interval", type=int, default=POLL_INTERVAL, help="Seconds between polling GitHub Actions.")
    p.add_argument("--verbose", "-v", action="store_true", help="Verbose output.")
    args = p.parse_args()

    repo_path = os.path.abspath(args.repo)
    remote_url = args.remote_url
    owner = args.owner
    repo_name = args.repo_name
    blacklist = args.blacklist
    dry_run = args.dry_run
    verbose = args.verbose
    poll_interval = args.poll_interval
    start_from = args.start_from

    token = os.environ.get("GITHUB_TOKEN")  # optional but recommended

    # Step 0: ensure clone present and fetch
    ensure_clone(repo_path, remote_url, verbose)

    # Step 1: list branches
    branches = list_branches(repo_path, verbose)
    branches = filter_branches(branches, blacklist, verbose)
    branches = sort_branches(branches, verbose)

    # If start_from provided, trim earlier branches
    if start_from:
        if start_from not in branches:
            print(f"[!] start-from branch '{start_from}' not found in branch list. Exiting.")
            sys.exit(2)
        idx = branches.index(start_from)
        branches = branches[idx:]

    if not branches:
        print("[!] No branches to process after filtering. Exiting.")
        sys.exit(0)

    # Today's date for label
    label_date = datetime.date.today().strftime("%Y%m%d")

    # main loop
    for branch in branches:
        print("\n" + "="*60)
        print(f"Processing branch: {branch}")
        try:
            changed = git_checkout_and_update(repo_path, branch, label_date, verbose, dry_run)
        except Exception as e:
            print(f"[ERROR] Git operation failed for branch {branch}: {e}")
            sys.exit(1)

        if not changed:
            print("[+] No changes to commit (label already up-to-date). Skipping push/poll for this branch.")
            if args.once:
                print("[+] --once set: exiting after one branch.")
                break
            else:
                # continue to next branch
                continue

        # After push, poll GitHub Actions for run status
        if dry_run:
            print("[DRY-RUN] Skipping GitHub polling because --dry-run set.")
            if args.once:
                break
            continue

        try:
            run = poll_workflow_until_done(owner, repo_name, branch, token, poll_interval, verbose)
            # If returned, it finished successfully -> continue
        except Exception as e:
            print(f"[!] Workflow failed for branch {branch}: {e}")
            # Optionally, you could create a GitHub issue here if token is provided.
            # For now: stop processing and notify via stdout
            print("[!] Stopping sequence due to failure. Fix the issue then re-run with --start-from", branch)
            sys.exit(3)

        print(f"[+] Branch {branch} finished SUCCESS — proceeding to next.")
        if args.once:
            print("[+] --once set: exiting after one branch.")
            break

    print("\nAll done (or reached end of branch list).")

if __name__ == "__main__":
    main()


