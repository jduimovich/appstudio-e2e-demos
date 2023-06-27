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
echo
echo "Installing AppName: $APPNAME into namespace: $NS"  

if [ "$AGGRESSIVE_PRUNE_PIPELINES" == "true" ] 
then 
  echo "Due to PVC Limits, this demo driver agressively removes pipelines"
  $SCRIPTDIR/prune-completed-pipelines.sh  
fi

MANIFESTS=$MANIFEST_DIR/$APPNAME
rm -rf $MANIFESTS
mkdir -p $MANIFESTS
 
if [ -d "$DEMODIR/app" ] 
then
  echo "App Definition Found, use $DEMODIR/app." 
  kubectl apply -n $NS -f $DEMODIR/app  
  cp $DEMODIR/app/*  $MANIFESTS 
else 
  $SCRIPTDIR/create-app.sh $APPNAME $NS
fi 
while ! kubectl get Application $APPNAME -n $NS &> /dev/null ; do 
  sleep 0.5
done  
MAX_WAIT=4
WAIT_COUNTER=0
while :
do
    STATUS=$(kubectl get application  $APPNAME -n $NS -o yaml | yq '.status.conditions[0].status') 
    if [ "$STATUS" == "True" ]
    then  
        break
    fi
    let WAIT_COUNTER++
    if [ "$WAIT_COUNTER" == "$MAX_WAIT" ]
    then 
        echo "Waiting for Application: $APPNAME to be ready  - TIMEOUT - continuing ... "
        break
    fi
    echo -n .
    sleep 0.5
done 

NEEDS_SECRET="false" 
for component in $DEMODIR/components/*
do 
  CONTAINER_IMAGE=$(yq '.spec.containerImage' $component)  
  if [ "$CONTAINER_IMAGE" != "null" ]; then 
    NEEDS_SECRET="true"
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
  fi 
  CNAME=$(yq '.metadata.name' $component)
  SRCURL=$(yq '.spec.source.git.url' $component)
  if [  "$SRCURL" != "null" ]
  then 
     yq '.metadata.annotations."image.redhat.com/generate"="'true'"' $component | \
     yq '.metadata.annotations.skip-initial-checks="'$QUICK_PIPELINES'"' | \
        tee $MANIFESTS/$CNAME.yaml | \
        kubectl apply -n $NS -f -
  else 
      echo "Binary only Component, specified image is $CONTAINER_IMAGE"
      cat $component |  
        tee $MANIFESTS/$CNAME.yaml | \
        kubectl apply -n $NS -f -
  fi
done

#If any components had a containerImage specified, then you need a secret
# user specifies an image, it must be for MY_QUAY_USER MY_QUAY_TOKEN accounts
if [ "$NEEDS_SECRET" == "true" ] 
then 
  SECRET_NAME=redhat-appstudio-staginguser-pull-secret
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

if [ -d "$DEMODIR/scenarios" ]
then
    echo "IntegrationTestScenarios exist with content."
    echo "Install IntegrationTestScenarios."
    kubectl apply -n $NS -f $DEMODIR/scenarios
    cp $DEMODIR/scenarios/*  $MANIFESTS/ 
fi
   
echo "Manifests: $MANIFESTS"  