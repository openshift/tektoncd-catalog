#!/usr/bin/env bash
#
# This will runs the E2E tests on OpenShift
#
set -e

# Maximin number of parallel tasks run at the same time
# # start from 0 so 4 => 5
MAX_NUMBERS_OF_PARALLEL_TASKS=4

# This is needed on openshift CI since HOME is read only and if we don't cache,
# it takes over 15s every kubectl query without caching.
KUBECTL_CMD="kubectl --cache-dir=/tmp/cache"

# Give these tests the priviliged rights
PRIVILEGED_TESTS="buildah buildpacks buildpacks-phases jib-gradle kaniko kythe-go s2i"

# Skip those tests when they really can't work in OpenShift
SKIP_TESTS="docker-build orka-full"

# Service Account used for image builder
SERVICE_ACCOUNT=builder

function check-service-endpoints() {
  service=${1}
  namespace=${2}
  echo "-----------------------"
  echo "checking ${namespace}/${service} service endpoints"
  count=0
  while [[ -z $(${KUBECTL_CMD} get endpoints ${service} -n ${namespace} -o jsonpath='{.subsets}') ]]; do
    # retry for 15 mins
    sleep 10
    if [[ $count -gt 90 ]]; then
      echo ${namespace}/${service} endpoints unavailable
      exit 1
    fi
    echo waiting for ${namespace}/${service} endpoints
    count=$(( count+1 ))
  done
}

# Create some temporary file to work with, we will delete them right after exiting
TMPF2=$(mktemp /tmp/.mm.XXXXXX)
TMPF=$(mktemp /tmp/.mm.XXXXXX)
clean() { rm -f ${TMP} ${TMPF2}; }
trap clean EXIT

source $(dirname $0)/../test/e2e-common.sh
cd $(dirname $(readlink -f $0))/..

# Install CI
[[ -z ${LOCAL_CI_RUN} ]] && install_pipeline_crd

# list tekton-pipelines-webhook service endpoints
check-service-endpoints "tekton-pipelines-webhook" "tekton-pipelines"

CURRENT_TAG=$(git describe --tags 2>/dev/null || true)

# in_array function: https://www.php.net/manual/en/function.in-array.php :-D
function in_array() {
    param=$1;shift
    for elem in $@;do
        [[ $param == $elem ]] && return 0;
    done
    return 1
}

function test_privileged {
    local cnt=0
    local task_to_tests=""

    # Run the privileged tests
    for runtest in $@;do
        btest=$(basename $(dirname $(dirname $runtest)))
        in_array ${btest} ${SKIP_TESTS} && { echo "Skipping: ${btest}"; continue ;}

        # Add here the pre-apply-taskrun-hook function so we can do our magic to add the serviceAccount on the TaskRuns,
        function pre-apply-taskrun-hook() {
            cp ${TMPF} ${TMPF2}
            python3 openshift/e2e-add-service-account.py ${SERVICE_ACCOUNT} < ${TMPF2} > ${TMPF}
            oc adm policy add-scc-to-user privileged system:serviceaccount:${tns}:${SERVICE_ACCOUNT} || true
        }
        unset -f pre-apply-task-hook || true

        task_to_tests="${task_to_tests} task/${runtest}/*/tests"

        if [[ ${cnt} == "${MAX_NUMBERS_OF_PARALLEL_TASKS}" ]];then
            echo "---"
            echo "Running privileged test: ${task_to_tests}"
            echo "---"

            test_task_creation ${task_to_tests}

            cnt=0
            task_to_tests=""
            continue
        fi

        cnt=$((cnt+1))
    done

    # Remaining task
    if [[ -n ${task_to_tests} ]];then
        echo "---"
        echo "Running privileged test: ${task_to_tests}"
        echo "---"

        test_task_creation ${task_to_tests}
    fi
}

function test_non_privileged {
    local cnt=0
    local task_to_tests=""

    # Run the non privileged tests
    for runtest in $@;do
        btest=$(basename $(dirname $(dirname $runtest)))
        in_array ${btest} ${SKIP_TESTS} && { echo "Skipping: ${btest}"; continue ;}
        in_array ${btest} ${PRIVILEGED_TESTS} && continue # We did them previously

        # Make sure the functions are not set anymore here or this will get run.
        unset -f pre-apply-taskrun-hook || true
        unset -f pre-apply-task-hook || true

        task_to_tests="${task_to_tests} ${runtest}"

        if [[ ${cnt} == "${MAX_NUMBERS_OF_PARALLEL_TASKS}" ]];then
            echo "---"
            echo "Running non privileged test: ${task_to_tests}"
            echo "---"

            test_task_creation ${task_to_tests}

            cnt=0
            task_to_tests=""
            continue
        fi

        cnt=$((cnt+1))
    done

    # Remaining task
    if [[ -n ${task_to_tests} ]];then
        echo "---"
        echo "Running non privileged test: ${task_to_tests}"
        echo "---"

        test_task_creation ${task_to_tests}
    fi
}

# Test if yamls can install
until test_yaml_can_install; do
  echo "-----------------------"
  echo 'retry test_yaml_can_install'
  echo "-----------------------"
  sleep 5
done
test_non_privileged $(\ls -1 -d task/*/*/tests)
test_privileged ${PRIVILEGED_TESTS}
