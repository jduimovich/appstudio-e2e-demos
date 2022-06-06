 #!/bin/bash
SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

TAG=$1 
echo "Triggering all the webhooks on the repos:"
oc get routes -o yaml | \
  yq e '.items[].spec.host | select(. == "el*")' - \
  | cat --number

oc get routes -o yaml | yq e '.items[].spec.host | select(. == "el*")' - | \
  xargs -n 1 -I {}  $SCRIPTDIR/trigger-webhook.sh {} "$TAG"
