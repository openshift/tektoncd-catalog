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

# in_array function: https://www.php.net/manual/en/function.in-array.php :-D
function in_array() {
    param=$1;shift
    for elem in $@;do
        [[ "$param" == "$elem" ]] && return 0;
    done
    return 1
}

# Test if yamls can install
test_yaml_can_install

# Run the privileged tests
for runtest in ${PRIVILEGED_TESTS};do
    echo "Running privileged test: ${runtest}"
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

    echo "Running non privileged test: ${btest}"
    test_task_creation ${runtest}
done
