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
echo "Installing AppName: $APPNAME"
echo "Namespace: $NS" 

kubectl get ns $NS &> /dev/null
ERR=$? 
if [  "$ERR" == "0" ]
then
  echo "Namespace $NS already exists"
else
$SCRIPTDIR/create-ns.sh $NS
fi


kubectl get secret docker-registry redhat-appstudio-registry-pull-secret -n $NS &> /dev/null
ERR=$? 
if [  "$ERR" == "0" ]
then
  echo "Secret docker-registry redhat-appstudio-registry-pull-secret already exists"
else
  echo "Install Secret for Quay.io" 
  oc create secret -n $NS docker-registry redhat-appstudio-registry-pull-secret \
    --docker-server="https://quay.io" \
    --docker-username=$MY_QUAY_USER \
    --docker-password=$MY_QUAY_TOKEN 
fi

if [ -d "$DEMODIR/app" ] 
then
  echo "App Definition Found, use $DEMODIR/app." 
  oc apply -n $NS -f $DEMODIR/app  
else
# use the directory to create an app
$SCRIPTDIR/create-app.sh $APPNAME $NS
fi
 
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
    STATUS=$(kubectl get application  $APPNAME -n $NS -o yaml | yq '.status.conditions[].status')
    if [ "$STATUS" == "True" ]
    then 
        break
    fi
    echo -n .
    sleep 1
done 

echo
echo "Install Components. "  
for component in $DEMODIR/components/*
do
   IMG=$(yq '.spec.containerImage' $component)
   B=$(basename $IMG) 
   echo "Setting Component Image using MY_QUAY_USER to quay.io/$MY_QUAY_USER/$B"
   yq '.spec.containerImage="quay.io/'$MY_QUAY_USER'/'$B'"' $component |
    yq '.spec.build.containerImage="quay.io/'$MY_QUAY_USER'/'$B'"' $component |
      oc apply -f -
done

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
 
oc get Application $APPNAME -n $NS -o yaml 