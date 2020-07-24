#!/usr/bin/env bash
#
# Detect which version of pipeline should be installed
# First it tries nightly
# If that doesn't work it tries previous releases (until the MAX_SHIFT variable)
# If not it exit 1
# It can take the argument --only-stable-release to not do nightly but only detect the pipeline version

MAX_SHIFT=2
NIGHTLY_RELEASE="https://raw.githubusercontent.com/openshift/tektoncd-pipeline/release-next/openshift/release/tektoncd-pipeline-nightly.yaml"
STABLE_RELEASE_URL='https://raw.githubusercontent.com/openshift/tektoncd-pipeline/${version}/openshift/release/tektoncd-pipeline-${version}.yaml'

function get_version {
    local shift=${1} # 0 is latest, increase is the version before etc...
    local version=$(curl -s https://api.github.com/repos/tektoncd/pipeline/releases | python -c "from pkg_resources import parse_version;import sys, json;jeez=json.load(sys.stdin);print(sorted([x['tag_name'] for x in jeez], key=parse_version, reverse=True)[${shift}])")
    echo $(eval echo ${STABLE_RELEASE_URL})
}

function tryurl {
    curl -s -o /dev/null -f ${1} || return 1
}

if [[ ${1} != "--only-stable-release" ]];then
   if tryurl ${NIGHTLY_RELEASE};then
       echo ${NIGHTLY_RELEASE}
       exit
   fi
fi

for shifted in `seq 0 ${MAX_SHIFT}`;do
    versionyaml=$(get_version ${shifted})
    if tryurl ${versionyaml};then
        echo ${versionyaml}
        exit 0
    fi
done

exit 1
