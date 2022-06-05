#!/bin/bash
SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
APPNAME=$1  
if [ -z "$APPNAME" ]
then
      echo Missing APPNAME Param
      exit -1 
fi  
echo "Create Application: $APPNAME." 
format=$(<$SCRIPTDIR/templates/application.yaml)
printf "$format\n" $APPNAME $APPNAME $APPNAME |  oc apply -f -   
  