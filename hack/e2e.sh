#!/bin/bash
SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

DEMODIR=$1 
BUNDLE=$2
if [ -z "$DEMODIR" ]
then
      echo Missing parameter Demo Directory 
      exit -1 
fi
if [ -z "$BUNDLE" ]
then
      BUNDLE=default 
fi 


APPNAME=$(basename $DEMODIR) 
# in App Studio use the single namespace 
# in regular full access cluster, use new namespaces ... 
WHICH_SERVER=$(oc whoami)
APP_STUDIO=$(echo "$WHICH_SERVER" | grep  "appstudio-")
echo "whoami: $WHICH_SERVER" 
if [ -n "$APP_STUDIO" ]
then
        echo Running in App Studio
        NS=$(oc project --short)
else   
        NS=$APPNAME
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
fi 
echo "Installing AppName: $APPNAME"
echo "Namespace: $NS"  
LOG=$(basename $DEMODIR) 
mkdir -p $SCRIPTDIR/logs/$LOG
echo "Log: $SCRIPTDIR/logs/$LOG" 

kubectl get ns $NS &> /dev/null
ERR=$? 
if [  "$ERR" == "0" ]
then
  echo "Namespace $NS already exists"
else
$SCRIPTDIR/create-ns.sh $NS
fi

if [ "$BUNDLE" = "hacbs" ]; then 
  echo
  echo "Use the HACBS pipelines in $NS"
  oc create configmap build-pipelines-defaults --from-literal=default_build_bundle=quay.io/redhat-appstudio/hacbs-templates-bundle:latest -o yaml --dry-run=client | \
    oc apply -n $NS -f -
else 
  echo
  echo "Use the default pipelines in $NS"
  oc delete configmap build-pipelines-defaults -n $NS   2>/dev/null
fi

if [ -n "$APP_STUDIO" ]
then
  echo "App Studio Mode does not install secrets"
else
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
fi

if [ -d "$DEMODIR/app" ] 
then
  echo "App Definition Found, use $DEMODIR/app." 
  oc apply -n $NS -f $DEMODIR/app  
  cp $DEMODIR/app/*  $SCRIPTDIR/logs/$LOG/ 
else
# use the directory to create an app
$SCRIPTDIR/create-app.sh $APPNAME $NS
fi
 
echo
echo "Creating Application: $APPNAME"
while ! kubectl get Application $APPNAME -n $NS &> /dev/null ; do
  echo -n . 
  sleep 1
done 
echo "Waiting for Application: $APPNAME to be ready."
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
# app studio format quay.io/redhat-appstudio/user-workload:NAMESPACE-COMPONENT 
# cluster format quay.io/$MY_QUAY_USER/COMPONENT
  if [ -n "$APP_STUDIO" ]
  then 
    QUAY_USER=redhat-appstudio
    COMP=user-workload:$NS-$B 
  else
    QUAY_USER=$MY_QUAY_USER
    COMP=$B 
  fi
  DEVFILEURL=$(yq '.spec.source.git.devfileUrl' $component)
  if [  "$DEVFILEURL" != "null" ]
  then  
    prefix="https://raw.githubusercontent.com/jduimovich"
    END=${DEVFILEURL#"$prefix"}
    if [  "$DEVFILEURL" != "$END" ]
    then
      GITUSER=$(git remote -v | tail -n 1 |  cut -d '/' -f 4  |tr -d '\n')
      NEWURL="https://raw.githubusercontent.com/$GITUSER$END"  
      if [  "$DEVFILEURL" != "$NEWURL" ]
      then
        newcomponent=$(mktemp)
        yq '.spec.source.git.devfileUrl="'$NEWURL'"' $component > $newcomponent 
        component=$newcomponent
        echo "Devfile reference modified to $NEWURL"
      fi
    else 
      echo "Devfile reference unmodified $DEVFILEURL"
    fi
  else
    echo "NO DEVFILEURL in component"
  fi
  FULL_IMAGE=quay.io/$QUAY_USER/$COMP
  echo "Setting Component Image using MY_QUAY_USER to $FULL_IMAGE"
   yq '.spec.containerImage="'$FULL_IMAGE'"' $component | \
    yq '.spec.build.containerImage="'$FULL_IMAGE'"' | \
      tee $SCRIPTDIR/logs/$LOG/$B.yaml | \
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
echo 
echo "Find the yaml used here: $SCRIPTDIR/logs/$LOG/"
ls -al $SCRIPTDIR/logs/$LOG/
echo "done"
echo