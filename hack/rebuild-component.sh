#!/bin/bash 
SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

C=$1
if [ -z "$C" ]
then 
  echo "Usage rebuild component"
  exit
fi  
NS=$2
if [ -z "$NS" ]
then
      echo "Usage app-name namespace"  
      exit -1 
fi
echo "Rebuild $C" 
kubectl patch component $C -n $NS   \
 --type=json -p='[{"op": "remove", "path": "/metadata/annotations/appstudio.openshift.io~1component-initial-build"}]' >/dev/null 2>&1 &

