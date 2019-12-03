DETECT_RELEASE_YAML=$(shell bash pipeline-latest-release.sh)
STABLE_RELEASE_YAML=$(shell bash pipeline-latest-release.sh --only-stable-release)
RELEASE_YAML=

# Temporary hack to use the stable release if nightly doesn't exist, in case release fails
test-e2e-downstream-nightly:
	make test-e2e-downstream RELEASE_YAML=$(DETECT_RELEASE_YAML)
.PHONY: test-e2e-downstream-nightly

test-e2e-downstream-stable:
	@make test-e2e-downstream RELEASE_YAML=$(STABLE_RELEASE_YAML)
.PHONY: test-e2e-downstream-stable

test-e2e-downstream:
	@env RELEASE_YAML=$(RELEASE_YAML) ./e2e-tests-openshift.sh
.PHONY: test-e2e-downstream
