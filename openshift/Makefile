NIGHTLY_YAML=https://raw.githubusercontent.com/openshift/tektoncd-pipeline/release-next/openshift/release/tektoncd-pipeline-nightly.yaml
STABLE_PIPELINE_VERSION=$(shell curl -s https://api.github.com/repos/tektoncd/pipeline/releases | python -c "import sys, json;x=json.load(sys.stdin);print(x[0]['tag_name'])")
STABLE_RELEASE_YAML=https://raw.githubusercontent.com/openshift/tektoncd-pipeline/release-$(STABLE_PIPELINE_VERSION)/openshift/release/tektoncd-pipeline-$(STABLE_PIPELINE_VERSION).yaml
RELEASE_YAML=

# Temporary hack to use the stable release if nightly doesn't exist, in case release fails
test-e2e-downstream-nightly:
	@yaml=$(NIGHTLY_YAML) ;\
	curl -s -o /dev/null -f $(NIGHTLY_YAML) || yaml=$(STABLE_RELEASE_YAML) ;\
	make test-e2e-downstream RELEASE_YAML=$$yaml
.PHONY: test-e2e-downstream-nightly

test-e2e-downstream-stable:
	@make test-e2e-downstream RELEASE_YAML=$(STABLE_RELEASE_YAML)
.PHONY: test-e2e-downstream-stable

test-e2e-downstream:
	@env RELEASE_YAML=$(RELEASE_YAML) ./e2e-tests-openshift.sh
	@env LOCAL_CI_RUN=true TEST_YAML_IGNORES="kaniko s2i buildah jib-maven" ../test/e2e-tests.sh
.PHONY: test-e2e-downstream