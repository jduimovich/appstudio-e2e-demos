#!/bin/bash
SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
NS=$1    
if [ -z "$NS" ]
then
      echo Missing Namespace Param
      exit -1 
fi

echo "Create NS: $NS." 
format=$(<$SCRIPTDIR/templates/namespace.yaml)
printf "$format\n" $NS  | oc apply -f -    

echo "Switched to Project: $NS." 
oc project $NS 