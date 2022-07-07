#!/bin/bash
SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
APPNAME=$1 
NS=$2 
if [ -z "$APPNAME" ]
then
      echo Missing APPNAME Param
      exit -1 
fi  
echo "Create Application from Template: $APPNAME in $NS" 
format=$(<$SCRIPTDIR/templates/application.yaml)
mkdir -p $SCRIPTDIR/logs/$APPNAME
printf "$format\n" $APPNAME $APPNAME $APPNAME | \
       tee $SCRIPTDIR/logs/$APPNAME/app.yaml | \
       oc apply -n $NS -f -   
  
echo "Created Application: $APPNAME in $NS" 