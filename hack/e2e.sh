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
NS=$APPNAME
echo "AppName = $APPNAME"
echo "NS = $NS" 
$SCRIPTDIR/create-ns.sh $NS

echo "Install Secret for Quay.io" 
oc create secret -n $NS docker-registry redhat-appstudio-registry-pull-secret \
  --docker-server="https://quay.io" \
  --docker-username=$MY_QUAY_USER \
  --docker-password=$MY_QUAY_TOKEN 


$SCRIPTDIR/create-app.sh $APPNAME 
 
echo
echo -n "Waiting for Application: "
while ! kubectl get Application $APPNAME -n $NS &> /dev/null ; do
  echo -n .
  sleep 1
done
echo "Application $APPNAME created" 
echo -n "Waiting for Application  Status True: "
while :
do
    STATUS=$(kubectl get Application  graphtuitous -o yaml | yq '.status.conditions[].status')
    if [ "$STATUS" == "True" ]
    then 
        break
    fi
    echo -n .
    sleep 1
done 

echo "Install Components. "  
oc apply -f $DEMODIR/components  

if [ -d "$DEMODIR/add-ons" ] 
then
    echo "Add-ons exist with content."
    echo "Install Add-ons (hack)."  
      # Extra stuff not provided by gitops/app studio
      # App Studio needs a concept of user "add-ons" via gitops/infrastructure components
      # Yaml only, not code
      format=$(<$SCRIPTDIR/templates/add-ons.yaml) 
      NM="$APPNAME-addon"
      RPATH=demos/$APPNAME/add-ons
      REPO_URL=$(git config --get remote.origin.url)
      printf "$format\n"  $NM $NS $RPATH $REPO_URL | oc apply -f -   
else
    echo "No Add-ons found for $APPNAME."
fi
 
oc get Application $APPNAME -o yaml 