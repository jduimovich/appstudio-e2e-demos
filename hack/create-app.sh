#!/bin/bash
SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
APPNAME=$1 
NS=$2 
if [ -z "$APPNAME" ]
then
      echo Missing APPNAME Param
      exit -1 
fi  
echo "Create Application from Template: $APPNAME" 
format=$(<$SCRIPTDIR/templates/application.yaml)
printf "$format\n" $APPNAME $APPNAME $APPNAME |  oc apply -n $NS -f -   
  