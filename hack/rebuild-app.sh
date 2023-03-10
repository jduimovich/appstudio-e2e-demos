#!/bin/bash 
SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

APP=$1
if [ -z "$APP" ]
then
      echo "Usage app-name namespace"  
      exit -1 
fi
NS=$2
if [ -z "$NS" ]
then
      echo "Usage app-name namespace"  
      exit -1 
fi


echo "All Components in $APP"

COMPONENTS=$(kubectl get components -n $NS -o yaml) 
LEN=$(echo "$COMPONENTS" | yq .items | yq length)  
let LEN--   
for COMPONENT_INDEX in  $(eval echo {0..$LEN})
do
    COMPONENT=$(echo "$COMPONENTS" | yq  ".items[$COMPONENT_INDEX]" -)   
    if [ "$COMPONENT" == "null" ] 
    then
        break
    fi
    APPNAME=$(echo "$COMPONENT" | yq  ".spec.application")  
    CNAME=$(echo "$COMPONENT" | yq ".metadata.name")
    if [ "$APPNAME" == "$APP" ] 
    then   
        $SCRIPTDIR/rebuild-component.sh $CNAME $NS 
    fi   
done    