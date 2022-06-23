 #!/bin/bash
SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

NS=$1
TAG=$2    
RTS=$(oc get routes  -n $NS -o yaml | yq e '.items[].metadata.name | select(. == "el*")')
for rt in $RTS 
do
  echo 
  C="${rt:2}" 
  REPO=$(oc get component  -n $NS $C -o yaml | yq '.spec.source.git.url') 
  echo "REPO Component $C NS $NS is $REPO"
  TAG=$(git ls-remote $REPO HEAD |  cut -f 1)
  echo "Repo: $REPO  "
  echo " TAG: $TAG"
  TRIGGER=$(oc get routes $rt -n $NS -o yaml | yq e '.spec.host')
  echo " TRIGGER: $TRIGGER"
  $SCRIPTDIR/trigger-webhook.sh "$TRIGGER" "$TAG"
done

#oc get routes -o yaml | yq e '.items[].spec.host | select(. == "el*")' - | \
#  xargs -n 1 -I {}  
