import os
import re
import subprocess
from pathlib import Path

REPO_URL = "https://github.com/mocacinno/bitcoin_core_docker"
REPO_NAME = "bitcoin_core_docker.git"
GHCR_IMAGE_PREFIX = "ghcr.io/mocacinno/mocacinno/bitcoin_core_docker"
DOCKERHUB_PREFIX = "mocacinno/btc_core"
BRANCH_REGEX = r"^v\d{1,2}\.\d{1,2}$"

def run(cmd, cwd=None):
    print(f"Running: {cmd}")
    subprocess.run(cmd, shell=True, check=True, cwd=cwd)

def clone_repo_if_needed():
    if not Path(REPO_NAME).exists():
        run(f"git clone --mirror {REPO_URL}")
    else:
        run("git remote update", cwd=REPO_NAME)

def get_filtered_branches():
    output = subprocess.check_output(
        ["git", "--git-dir", REPO_NAME, "for-each-ref", "--format=%(refname:short)", "refs/heads/"],
        universal_newlines=True
    )
    raw_branches = output.splitlines()
    print("Raw branches from git:")
    for b in raw_branches:
        print(f"  > {b}")

    # Adjust regex if needed
    filtered = [b for b in raw_branches if re.match(BRANCH_REGEX, b)]
    print(f"Filtered branches: {filtered}")
    return filtered

def generate_alternative_tag(branchname):
    return f"v0.{branchname[1:]}"  # Strip 'v' and prepend 'v0.'

def docker_pull_tag_push(branchname):
    source_image = f"{GHCR_IMAGE_PREFIX}:{branchname}"
    alt_tag = generate_alternative_tag(branchname)
    tag1 = f"{DOCKERHUB_PREFIX}:{branchname}"
    tag2 = f"{DOCKERHUB_PREFIX}:{alt_tag}"

    run(f"docker pull {source_image}")
    run(f"docker tag {source_image} {tag1}")
    run(f"docker tag {source_image} {tag2}")
    run(f"docker push {tag1}")
    run(f"docker push {tag2}")

def main():
    clone_repo_if_needed()
    branches = get_filtered_branches()
    print(f"Filtered branches: {branches}")
    for branch in branches:
        try:
            docker_pull_tag_push(branch)
        except subprocess.CalledProcessError as e:
            print(f"Error processing {branch}: {e}")

if __name__ == "__main__":
    main()
