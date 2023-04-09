#!/bin/bash 
SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
 
NS=$1
if [ -z "$NS" ]
then
      echo "Usage namespace"  
      exit -1 
fi


echo "All Components in $NS" 
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
    CNAME=$(echo "$COMPONENT" | yq ".metadata.name")  
    $SCRIPTDIR/rebuild-component.sh $CNAME $NS  
done    