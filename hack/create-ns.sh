#!/bin/bash
SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source $SCRIPTDIR/config.sh 

NS=$1    
if [ -z "$NS" ]
then
      echo Missing Namespace Param
      exit -1 
fi

echo "Create NS: $NS." 
format=$(<$SCRIPTDIR/templates/namespace.yaml) 
MANIFESTS=$MANIFEST_DIR/$NS
mkdir -p $MANIFESTS
printf "$format\n" $NS  | \
      tee $MANIFESTS/namespace.yaml | \
      kubectl apply -f -     