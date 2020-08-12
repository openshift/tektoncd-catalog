NIGHTLY_PIPELINE_RELEASE_YAML=$(shell bash pipeline-latest-release.sh)
NIGHTLY_PIPELINE_VERSION=$(shell bash pipeline-latest-release.sh -v)
STABLE_PIPELINE_RELEASE_YAML=$(shell bash pipeline-latest-release.sh -s)
STABLE_PIPELINE_VERSION=$(shell bash pipeline-latest-release.sh -s -v)
RELEASE_YAML=
PIPELINE_VERSION=

# Temporary hack to use the stable release if nightly doesn't exist, in case release fails
test-e2e-downstream-nightly:
	make test-e2e-downstream RELEASE_YAML=$(NIGHTLY_PIPELINE_RELEASE_YAML) PIPELINE_VERSION=$(NIGHTLY_PIPELINE_VERSION)
.PHONY: test-e2e-downstream-nightly

test-e2e-downstream-stable:
	make test-e2e-downstream RELEASE_YAML=$(STABLE_PIPELINE_RELEASE_YAML) PIPELINE_VERSION=$(STABLE_PIPELINE_VERSION)
.PHONY: test-e2e-downstream-stable

test-e2e-downstream:
	env RELEASE_YAML=$(RELEASE_YAML) PIPELINE_VERSION=$(PIPELINE_VERSION) ./e2e-tests-openshift.sh
.PHONY: test-e2e-downstream
