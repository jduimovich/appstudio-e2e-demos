 #!/bin/bash
SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

C=$1
NS=$2   
if [ -z "$NS" ]
then
  NS=$(oc project --short)
fi  
rt=el$C
REPO=$(oc get component  -n $NS $C -o yaml | yq '.spec.source.git.url') 
echo "REPO Component $C NS $NS is $REPO"
TAG=$(git ls-remote $REPO HEAD |  cut -f 1)
echo "Repo: $REPO  "
echo " TAG: $TAG"
TRIGGER=$(oc get routes $rt -n $NS -o yaml | yq e '.spec.host')
echo " TRIGGER: $TRIGGER"
$SCRIPTDIR/trigger-webhook.sh "$TRIGGER" "$TAG"
