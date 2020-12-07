#!/usr/bin/env bash

# Copyright 2018 The Tekton Authors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Helper functions for E2E tests.

# Check if we have a specific RELEASE_YAML global environment variable to use
# instead of detecting the latest released one from tektoncd/pipeline releases

RELEASE_YAML=${RELEASE_YAML:-}

source $(dirname $0)/../vendor/github.com/tektoncd/plumbing/scripts/e2e-tests.sh

# Add an internal registry as sidecar to a task so we can upload it directly
# from our tests withouth having to go to an external registry.
function add_sidecar_registry() {
    cp ${1} ${TMPF}.read

    cat ${TMPF}.read | python3 -c 'import yaml;f=open(0, encoding="utf-8"); data=yaml.load(f.read(), Loader=yaml.FullLoader);data["spec"]["sidecars"]=[{"image":"registry", "name": "registry"}];print(yaml.dump(data, default_flow_style=False));' > ${TMPF}
    rm -f ${TMPF}.read
}

function add_task() {
    local array path_version task
    task=${1}
    if [[ "${2}" == "latest" ]];then
        array=($(echo task/${task}/*/|sort -u))
        path_version=${array[-1]}
	else
		path_version=task/${task}/${2}
        if [[ ! -d ${path_version} ]];then
            echo "I could not find version '${2}' for the task '${task}' in ./task/"
            exit 1
        fi
	fi
    kubectl -v=10 -n "${tns}" apply -f "${path_version}"/"${task}".yaml
}

function install_pipeline_crd() {
  local latestreleaseyaml
  echo ">> Deploying Tekton Pipelines"
  if [[ -n ${RELEASE_YAML} ]];then
	latestreleaseyaml=${RELEASE_YAML}
  else
    latestreleaseyaml="https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml"
  fi
  [[ -z ${latestreleaseyaml} ]] && fail_test "Could not get latest released release.yaml"
  kubectl -v=10 apply -f ${latestreleaseyaml} ||
    fail_test "Build pipeline installation failed"

  # Make sure thateveything is cleaned up in the current namespace.
  for res in pipelineresources tasks pipelines taskruns pipelineruns; do
    kubectl -v=10 delete --ignore-not-found=true ${res}.tekton.dev --all
  done

  # Wait for pods to be running in the namespaces we are deploying to
  wait_until_pods_running tekton-pipelines || fail_test "Tekton Pipeline did not come up"
}

function test_yaml_can_install() {
    # Validate that all the Task CRDs in this repo are valid by creating them in a NS.
    readonly ns="task-ns"
    all_tasks="$*"
    kubectl -v=10 create ns "${ns}" || true
    local runtest
    for runtest in ${all_tasks}; do
        # remove task/ from beginning
        local runtestdir=${runtest#*/}
        # remove /0.1/tests from end
        local testname=${runtestdir%%/*}
        runtest=${runtest//tests}
        runtest="${runtest}${testname}.yaml"
        skipit=
        for ignore in ${TEST_YAML_IGNORES};do
            [[ ${ignore} == "${testname}" ]] && skipit=True
        done
        [[ -n ${skipit} ]] && break
        echo "Checking ${testname}"
        kubectl -v=10 -n ${ns} apply -f <(sed "s/namespace:.*/namespace: task-ns/" "${runtest}")
    done
}

function show_failure() {
    local testname=$1 tns=$2

    echo "FAILED: ${testname} task has failed to comeback properly" ;
    echo "--- Task Dump"
    kubectl -v=10 get -n ${tns} task -o yaml
    echo "--- Pipeline Dump"
    kubectl -v=10 get -n ${tns} pipeline -o yaml
    echo "--- PipelineRun Dump"
    kubectl -v=10 get -n ${tns} pipelinerun -o yaml
    echo "--- TaskRun Dump"
    kubectl -v=10 get -n ${tns} taskrun -o yaml
    echo "--- Container Logs"
    for pod in $(kubectl -v=10 get pod -o name -n ${tns}); do
        kubectl -v=10 logs --all-containers -n ${tns} ${pod} || true
    done
    exit 1

}
function test_task_creation() {
    local runtest
    for runtest in $@;do
        # remove task/ from beginning
        local runtestdir=${runtest#*/}
        # remove /0.1/tests from end
        local testname=${runtestdir%%/*}
        # get version of the task
        local version=$(basename $(basename $(dirname $runtest)))
        # check version is in given format
        [[ ${version} =~ ^[0-9]+\.[0-9]+$ ]] || { echo "ERROR: version of the task is not set properly"; exit 1;}
        # replace . with - in version as not supported in namespace name
        version="$( echo $version | tr '.' '-' )"
        local tns="${testname}-${version}"
        local skipit=
        local maxloop=60 # 10 minutes max

        for ignore in ${TEST_TASKRUN_IGNORES};do
            [[ ${ignore} == ${testname} ]] && skipit=True
        done

        # remove /tests from end
        local taskdir=${runtest%/*}

        # check whether test folder exists or not inside task dir
        # if not then run the tests for next task (if any)
        [ ! -d $runtest ] && skipit=True

        ls ${taskdir}/*.yaml 2>/dev/null >/dev/null || skipit=True

        cat ${taskdir}/*.yaml | grep 'tekton.dev/deprecated: \"true\"' && skipit=True

        [[ -n ${skipit} ]] && continue

        kubectl -v=10 create namespace ${tns}

        # Install the task itself first
        for yaml in ${taskdir}/*.yaml;do
            cp ${yaml} ${TMPF}
            [[ -f ${taskdir}/tests/pre-apply-task-hook.sh ]] && source ${taskdir}/tests/pre-apply-task-hook.sh
            function_exists pre-apply-task-hook && pre-apply-task-hook

            [[ -d ${taskdir}/tests/fixtures ]] && {
                cat <<EOF>>${TMPF}
  sidecars:
  - image: quay.io/chmouel/go-rest-api-test
    name: go-rest-api
    env:
      - name: CONFIG
        value: |
$(cat ${taskdir}/tests/fixtures/*.yaml|sed 's/^/          /')
EOF
            }

            kubectl -v=10 -n ${tns} create -f ${TMPF}
        done

        # Install resource and run
        for yaml in ${runtest}/*.yaml;do
            cp ${yaml} ${TMPF}
            [[ -f ${taskdir}/tests/pre-apply-taskrun-hook.sh ]] && source ${taskdir}/tests/pre-apply-taskrun-hook.sh
            function_exists pre-apply-taskrun-hook && pre-apply-taskrun-hook
            kubectl -v=10 -n ${tns} create -f ${TMPF}
        done

        local cnt=0
        local all_status=''
        local reason=''
        # we temporary disable the debug output here since it fill up the
        # logs a lot while waiting for the task to fail/succeed
        set +x
        echo "$(date '+%x %Hh%M:%S') Waiting for task ${testname} to finish successfully."
        while true;do
            [[ ${cnt} == ${maxloop} ]] && show_failure ${testname} ${tns}

            # sometimes we don't get all_status and reason in one go so
            # wait until we get the reason and all_status for 5 iterations
            for _ in {1..5}; do
                all_status=$(kubectl -v=10 get -n ${tns} pipelinerun --output=jsonpath='{.items[*].status.conditions[*].status}')
                reason=$(kubectl -v=10 get -n ${tns} pipelinerun --output=jsonpath='{.items[*].status.conditions[*].reason}')
                [[ ! -z ${all_status} ]] && [[ ! -z ${reason} ]] && break
            done

            if [[ -z ${all_status} && -z ${reason} ]];then
                for _ in {1..5}; do
                    all_status=$(kubectl -v=10 get -n ${tns} taskrun --output=jsonpath='{.items[*].status.conditions[*].status}')
                    reason=$(kubectl -v=10 get -n ${tns} taskrun --output=jsonpath='{.items[*].status.conditions[*].reason}')
                    [[ ! -z ${all_status} ]] && [[ ! -z ${reason} ]] && break
                done
            fi

            if [[ -z ${all_status} || -z ${reason} ]];then
                echo -n "Could not find a created taskrun or pipelinerun in ${tns}"
            fi

            breakit=True
            for status in ${all_status};do

                [[ ${status} == *ERROR || ${reason} == *Fail* || ${reason} == Couldnt* ]] && show_failure ${testname} ${tns}

                if [[ ${status} != True ]];then
                    breakit=
                fi
            done

            if [[ ${breakit} == True ]];then
                echo "$(date '+%x %Hh%M:%S') SUCCESS: ${testname} pipelinerun has successfully executed" ;
                break
            fi

            sleep 10
            cnt=$((cnt+1))
        done
        set -x

        # Delete namespace unless we specify the CATALOG_TEST_SKIP_CLEANUP env
        # variable so we can debug in case the user needs it.
        [[ -z ${CATALOG_TEST_SKIP_CLEANUP} ]] && kubectl -v=10 delete ns ${tns}
    done
}
