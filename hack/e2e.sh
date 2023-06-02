#!/bin/bash
SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source $SCRIPTDIR/config.sh 

DEMODIR=$1  
if [ -z "$DEMODIR" ]
then
      echo Missing parameter Demo Directory 
      exit -1 
fi 

APPNAME=$(basename $DEMODIR)    
source $SCRIPTDIR/select-ns.sh $APPNAME 
echo "Installing AppName: $APPNAME into namespace: $NS"  

if [ "$AGGRESSIVE_PRUNE_PIPELINES" == "true" ] 
then 
  echo "Due to PVC Limits, this demo driver agressively removes pipelines"
  $SCRIPTDIR/prune-completed-pipelines.sh  
fi

MANIFESTS=$MANIFEST_DIR/$APPNAME
rm -rf $MANIFESTS
mkdir -p $MANIFESTS
echo "Manifests can be found in: $MANIFESTS" 

SECRET_NAME=redhat-appstudio-staginguser-pull-secret
if [ "$USE_REDHAT_QUAY" != "true" ] 
then 
  kubectl get secret $SECRET_NAME -n $NS &> /dev/null
  ERR=$? 
  if [  "$ERR" == "0" ]
  then
    echo "Secret docker-registry $SECRET_NAME already exists"
  else
    echo "Install Secret for user $MY_QUAY_USER in Quay.io" 
    kubectl create secret -n $NS docker-registry $SECRET_NAME \
      --docker-server="https://quay.io" \
      --docker-username=$MY_QUAY_USER \
      --docker-password=$MY_QUAY_TOKEN  2>/dev/null
  fi
  oc secrets link appstudio-pipeline $SECRET_NAME  
fi


if [ -d "$DEMODIR/app" ] 
then
  echo "App Definition Found, use $DEMODIR/app." 
  kubectl apply -n $NS -f $DEMODIR/app  
  cp $DEMODIR/app/*  $MANIFESTS 
else 
  $SCRIPTDIR/create-app.sh $APPNAME $NS
fi 
while ! kubectl get Application $APPNAME -n $NS &> /dev/null ; do 
  sleep 1
done 
echo -n "Waiting for Application: $APPNAME to be ready."
MAX_WAIT=5
WAIT_COUNTER=1
while :
do
    STATUS=$(kubectl get application  $APPNAME -n $NS -o yaml | yq '.status.conditions[0].status') 
    if [ "$STATUS" == "True" ]
    then 
        echo
        break
    fi
    let WAIT_COUNTER++
    if [ "$WAIT_COUNTER" == "$MAX_WAIT" ]
    then 
        echo "WAIT LOOP TIMEOUT - continuing ... "
        break
    fi
    echo -n .
    sleep 1
done 
 
echo "Install Components. "   
for component in $DEMODIR/components/*
do
   IMG=$(yq '.spec.containerImage' $component)
   B=$(basename $IMG)
# app studio format quay.io/redhat-appstudio/user-workload:NAMESPACE-COMPONENT 
# cluster format quay.io/$MY_QUAY_USER/COMPONENT
  if [ "$USE_REDHAT_QUAY" == "true" ] 
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
    echo "No devfile in this repo for this component"
  fi 
  SRCURL=$(yq '.spec.source.git.url' $component)
  if [  "$SRCURL" != "null" ]
  then
    FULL_IMAGE=quay.io/$QUAY_USER/$COMP
    echo "Setting Component Image using MY_QUAY_USER to $FULL_IMAGE"
    yq '.spec.containerImage="'$FULL_IMAGE'"' $component | \
     yq '.metadata.annotations.skip-initial-checks="'$QUICK_PIPELINES'"' | \
        tee $MANIFESTS/$B.yaml | \
        kubectl apply -n $NS -f -
  else
      IMAGE=$(yq '.spec.containerImage' $component)
      echo "Binary only Component,  reference image unmodified $IMAGE"
      cat $component |  
        tee $MANIFESTS/$B.yaml | \
        kubectl apply -n $NS -f -
  fi
done

if [ -d "$DEMODIR/scenarios" ]
then
    echo "IntegrationTestScenarios exist with content."
    echo "Install IntegrationTestScenarios."
    kubectl apply -n $NS -f $DEMODIR/scenarios
    cp $DEMODIR/scenarios/*  $MANIFESTS/
else
    echo "No IntegrationTestScenarios found for $APPNAME."
fi
  
echo 
echo "Find the yaml used here: $MANIFESTS/"
ls -al $MANIFESTS/
echo "done"
echo