#!/bin/bash
SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
NS=$1  
if [ -z "$NS" ]
then
      echo Missing Namespace Param
      exit -1 
fi
ENVNAME=$2    
if [ -z "$ENVNAME" ]
then
      ENVNAME="Development" 
fi

kubectl get Environment $ENVNAME -n $NS &> /dev/null
ERR=$? 
if [  "$ERR" == "0" ]
then
      echo "Environment $ENVNAME already created"
      exit 0
fi

ENVFILE=$(mktemp)
cat << EOF > $ENVFILE 
apiVersion: appstudio.redhat.com/v1alpha1
kind: Environment
metadata: 
  name: $ENVNAME
  namespace: "$NS"   
spec:
  deploymentStrategy: AppStudioAutomated
  displayName: $ENVNAME
  type: poc 
EOF
 
kubectl apply -f $ENVFILE    