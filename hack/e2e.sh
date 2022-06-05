#!/bin/bash
SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

DEMODIR=$1 
if [ -z "$DEMODIR" ]
then
      echo Missing parameter Demo Directory 
      exit -1 
fi
if [ -z "$MY_QUAY_USER" ]
then
      echo Missing env MY_QUAY_USER
      exit -1 
fi
if [ -z "$MY_QUAY_TOKEN" ]
then
      echo Missing env MY_QUAY_USER 
      exit -1 
fi
 
APPNAME=$(basename $DEMODIR) 
NS=$APPNAME-ns
echo "AppName = $APPNAME"
echo "NS = $NS"

format=$(<$SCRIPTDIR/templates/namespace.yaml)
printf "$format\n" $NS  | \
    oc apply -f -   
oc project $NS

echo "Install Secret for Quay.io" 
oc create secret -n $NS docker-registry redhat-appstudio-registry-pull-secret \
  --docker-server="https://quay.io" \
  --docker-username=$MY_QUAY_USER \
  --docker-password=$MY_QUAY_TOKEN 
   
echo "Install Application. " 
format=$(<$SCRIPTDIR/templates/application.yaml)
printf "$format\n" $APPNAME $APPNAME $APPNAME | \
    oc apply -f -   
 
echo
echo -n "Waiting for Application: "
while ! kubectl get Application $APPNAME -n $NS &> /dev/null ; do
  echo -n .
  sleep 1
done
echo "Application $APPNAME ready" 
echo "Install Components. "  
oc apply -f $DEMODIR/components 
# Extra stuff not provided by gitops/app studio
# this should be use enabled "add-ons" via gitops/infrastructure components

echo "Install Add-ons (hack)."  
format=$(<$SCRIPTDIR/templates/add-ons.yaml) 
NM="$APPNAME-addon"
RPATH=demos/$APPNAME/add-ons
REPO_URL=$(git config --get remote.origin.url)
printf "$format\n"  $NM $NS $RPATH $REPO_URL | \
    oc apply -f -   
 