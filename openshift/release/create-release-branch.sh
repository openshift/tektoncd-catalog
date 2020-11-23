#!/bin/bash -e
set -eu

tag=$1
tag_regexp="^v([0-9]+)\.([0-9]+)\.([0-9]+)"

if [[ -z ${tag} ]];then
    echo "You need specify a tag like v0.9.1"
    exit 1
fi

if [[ ! $tag =~ $tag_regexp ]];then
    echo "\"$tag\" is wrong format. Must have proper format like v1.2.3"
    exit 1
fi

release=release-v${BASH_REMATCH[1]}.${BASH_REMATCH[2]}

echo "===== Resetting branch ${release} based on ${tag}"

# Fetch the latest tags and checkout a new branch from the wanted tag.
git fetch upstream --tags

echo "===== Checkout upstream/master as base"
git checkout --no-track -B "${release}" upstream/master

echo "===== Adding openshift specific files from openshift/master"
git fetch openshift master
git checkout openshift/master -- openshift OWNERS_ALIASES OWNERS

git add openshift OWNERS_ALIASES OWNERS
git commit -m "Add openshift specific files based on pipeline ${tag}"

echo "===== Creating tag ${tag}"
git tag --force ${tag}

echo "===== Pushing branch '${release}' to openshift remote"
git push openshift ${release}

echo "===== Pushing tag '${tag}' to openshift remote"
git push --tags openshift ${tag}

echo "===== Done"
echo "$(git remote get-url openshift)/tree/${release}"
