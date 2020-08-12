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
only_stable_release=
show_only_version=

function get_version {
    local shift=${1} # 0 is latest, increase is the version before etc...
    local version=$(curl -s https://api.github.com/repos/tektoncd/pipeline/releases | python -c "from pkg_resources import parse_version;import sys, json;jeez=json.load(sys.stdin);print(sorted([x['tag_name'] for x in jeez], key=parse_version, reverse=True)[${shift}])")
    if [[ -n ${show_only_version} ]];then
        echo ${version}
    else
        echo $(eval echo ${STABLE_RELEASE_URL})
    fi
}

function tryurl {
    curl -s -o /dev/null -f ${1} || return 1
}

while getopts "sv" o; do
    case "${o}" in
        s)
            only_stable_release=true
            ;;
        v)
            show_only_version=true
            ;;
        *)
            echo "Invalid option"; exit 1;
            ;;
    esac
done
shift $((OPTIND-1))


if [[ -n ${only_stable_release} ]];then
   if tryurl ${NIGHTLY_RELEASE};then
       if [[ -n ${show_only_version} ]];then
           echo nightly
       else
           echo ${NIGHTLY_RELEASE}
       fi
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
