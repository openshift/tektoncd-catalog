#!/usr/bin/env python
# This will add a security context via PodTemplate to a TaskRun/PipelineRun with pyyaml via
# STDIN/STDOUT eg:
#
# python openshift/e2e-add-privileged-context.py < run.yaml > newfile.yaml
#
import yaml
import sys
data = list(yaml.safe_load_all(sys.stdin))
podTemplate = {
    'securityContext': {
        'runAsNonRoot': False,
        'runAsUser': 0,
    }
}
for x in data:
    if not x:
        continue
    if x['kind'] in ('PipelineRun', 'TaskRun'):
        x['spec']['podTemplate'] = podTemplate
print(yaml.dump_all(data, default_flow_style=False))
