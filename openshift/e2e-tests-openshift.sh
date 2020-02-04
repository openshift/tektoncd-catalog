#!/usr/bin/env bash
#
# This will runs the E2E tests on OpenShift
#
set -e

# Create some temporary file to work with, we will delete them right after exiting
TMPF2=$(mktemp /tmp/.mm.XXXXXX)
TMPF=$(mktemp /tmp/.mm.XXXXXX)
clean() { rm -f ${TMP} ${TMPF2}; }
trap clean EXIT

source $(dirname $0)/../test/e2e-common.sh
cd $(dirname $(readlink -f $0))/..

# Give these tests the priviliged rights
PRIVILEGED_TESTS="buildah kaniko s2i"

# Skip Those
SKIP_TESTS=""

# Service Account used for image builder
SERVICE_ACCOUNT=builder

# Install CI
[[ -z ${LOCAL_CI_RUN} ]] && install_pipeline_crd

# Pipelines Catalog Repository
PIPELINES_CATALOG_URL=https://github.com/openshift/pipelines-catalog/
PIPELINES_CATALOG_REF=origin/master
PIPELINES_CATALOG_DIRECTORY=./openshift/pipelines-catalog
PIPELINES_CATALOG_IGNORE="s2i-dotnet-1"
PIPELINES_CATALOG_PRIVILIGED_TASKS="s2i-*"

CURRENT_TAG=$(git describe --tags 2>/dev/null || true)
if [[ -n ${CURRENT_TAG} ]];then
    PIPELINES_CATALOG_REF=origin/release-$(echo ${CURRENT_TAG}|sed -e 's/.*\(v[0-9]*\.[0-9]*\).*/\1/')
fi

# Add PIPELINES_CATALOG in here so we can do the CI all together.
# We checkout the repo in ${PIPELINES_CATALOG_DIRECTORY}, merge them in the main
# repos and launch the tests.
function pipelines_catalog() {
    set -x
    local oldRepoRootDir
    local ptest parent

    [[ -d ${PIPELINES_CATALOG_DIRECTORY} ]] || \
        git clone ${PIPELINES_CATALOG_URL} ${PIPELINES_CATALOG_DIRECTORY}

    pushd ${PIPELINES_CATALOG_DIRECTORY} >/dev/null && \
        git reset --hard ${PIPELINES_CATALOG_REF} &&
        popd >/dev/null

    # NOTE(chmouel): The functions doesnt support argument so we can't just leave the test in
    # ${PIPELINES_CATALOG_DIRECTORY} we need to have it in the top dir, TODO: fix the functions
    for ptest in ${PIPELINES_CATALOG_DIRECTORY}/*/tests;do
        parent=$(dirname ${ptest})
        base=$(basename ${parent})
        in_array ${base} ${PIPELINES_CATALOG_IGNORE} && { echo "Skipping: ${base}"; continue ;}
        [[ -d ./${base} ]] || cp -a ${parent} ./${base}

        # TODO(chmouel): Add S2I Images as PRIVILEGED_TESTS, that's not very
        # flexible and we may want to find some better way.
        [[ ${ptest} == ${PIPELINES_CATALOG_DIRECTORY}/${PIPELINES_CATALOG_PRIVILIGED_TASKS} ]] && \
            PRIVILEGED_TESTS="${PRIVILEGED_TESTS} ${base}"
    done
    set +x
}

# in_array function: https://www.php.net/manual/en/function.in-array.php :-D
function in_array() {
    param=$1;shift
    for elem in $@;do
        [[ "$param" == "$elem" ]] && return 0;
    done
    return 1
}

# Checkout Pipelines Catalog and test
pipelines_catalog

# Test if yamls can install
test_yaml_can_install

# Run the privileged tests
for runtest in ${PRIVILEGED_TESTS};do
    echo "-----------------------"
    echo "Running privileged test: ${runtest}"
    echo "-----------------------"
    # Add here the pre-apply-taskrun-hook function so we can do our magic to add the serviceAccount on the TaskRuns,
    function pre-apply-taskrun-hook() {
        cp ${TMPF} ${TMPF2}
        python openshift/e2e-add-service-account.py ${SERVICE_ACCOUNT} < ${TMPF2} > ${TMPF}
        grep -q TaskRun ${TMPF} && oc adm policy add-scc-to-user privileged system:serviceaccount:${tns}:${SERVICE_ACCOUNT} || true
    }
    unset -f pre-apply-task-hook || true

    test_task_creation ${runtest}/tests
done

# Run the non privileged tests
for runtest in */tests;do
    btest=$(basename $(dirname $runtest))
    in_array ${btest} ${SKIP_TESTS} && { echo "Skipping: ${btest}"; continue ;}
    in_array ${btest} ${PRIVILEGED_TESTS} && continue # We did them previously

    # Make sure the functions are not set anymore here or this will get run.
    unset -f pre-apply-taskrun-hook || true
    unset -f pre-apply-task-hook || true

    echo "---------------------------"
    echo "Running non privileged test: ${btest}"
    echo "---------------------------"
    test_task_creation ${runtest}
done
