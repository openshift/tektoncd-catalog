#!/usr/bin/env bash

# Synchs the release-next branch to master and then triggers CI
# Usage: update-to-head.sh

set -e
REPO_NAME=`basename $(git rev-parse --show-toplevel)`
BRANCH=${BRANCH:-master}
OPENSHIFT_REMOTE=${OPENSHIFT_REMOTE:-openshift}

# Reset release-next to upstream/master.
git fetch upstream ${BRANCH}
git checkout upstream/${BRANCH} --no-track -B release-next

# Update openshift's master and take all needed files from there.
git fetch ${OPENSHIFT_REMOTE} master
git checkout ${OPENSHIFT_REMOTE}/master openshift OWNERS_ALIASES OWNERS
git add openshift OWNERS_ALIASES OWNERS
git commit -m ":open_file_folder: Update openshift specific files."

git push -f ${OPENSHIFT_REMOTE} HEAD:release-next

# Trigger CI
git checkout release-next --no-track -B release-next-ci
date > ci
git add ci
git commit -m ":robot: Triggering CI on branch 'release-next' after synching to upstream/master"
git push -f ${OPENSHIFT_REMOTE} HEAD:release-next-ci

if hash hub 2>/dev/null; then
   hub pull-request --no-edit -l "kind/sync-fork-to-upstream" -b openshift/${REPO_NAME}:release-next -h openshift/${REPO_NAME}:release-next-ci
else
   echo "hub (https://github.com/github/hub) is not installed, so you'll need to create a PR manually."
fi
