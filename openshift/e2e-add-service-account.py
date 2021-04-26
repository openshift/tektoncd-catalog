#!/usr/bin/env python
# This will add a serviceAccount to a TaskRun/PipelineRun with pyyaml via
# STDIN/STDOUT eg:
#
# python openshift/e2e-add-service-account-tr.py \
#   SERVICE_ACCOUNT < run.yaml > newfile.yaml
#
import yaml
import sys
data = list(yaml.safe_load_all(sys.stdin))
for x in data:
    if not x:
        continue
    if x['kind'] in ('PipelineRun', 'TaskRun'):
        x['spec']['serviceAccountName'] = sys.argv[1]
print(yaml.dump_all(data, default_flow_style=False))
