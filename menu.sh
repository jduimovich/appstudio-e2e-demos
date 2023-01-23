#!/usr/bin/env bash
declare -A DEMOS
COUNTER=0
for dir in demos/*
do
   if [ -d $dir ]; then    
      let COUNTER++  
      DEMOS["$COUNTER"]=$(basename $dir)
   fi
done
echo "$COUNTER demos found."  

# set env vars for various options, kcp,crc,appstudio-pre-kcp
function updateserverinfo() {
    source ./hack/select-ns.sh default  
}

# utilities (verbose) for menus, keep separate.
source hack/utils-for-menu.sh
  
function showroutes() { 
    NS=$1  
    ROUTES=$(kubectl get routes -n $NS  -o yaml  2>/dev/null | yq '.items[].spec.host | select(. != "el*")')
    if [ "$ROUTES" != "" ]
    then
        printf "\nRoutes:\n"   
        echo $ROUTES | xargs -n 1 printf "\tRoute: https://%s\n"
    else 
        printf "\nNo Routes found in $NS:\n"   
    fi 
        
}


function showallappstatus() {
    ALL_APPS=$(kubectl get  application.appstudio.redhat.com -o yaml -n $NS | yq '.items[].metadata.name' | xargs -n1 echo -n " " )
    echo 
    for app in $ALL_APPS
    do   
        showappstatus $app $NS
    done   
}

function showResourceName() {
        RES=$1
        ALLRS=$(kubectl get $RES -n $NS -o yaml | yq ".items[0].metadata.name") 
        NAME=$ALLRS
        if [ $ALLRS == "null" ]; then
            ALLRS="(no $RES found)"
            NAME=""
        fi
        printf "\n%s: %s\n" "$RES" "$ALLRS"
        printf  "Use CLI for more info: %s\n"  "kubectl get $RES $NAME -o yaml"
}



function showappstatus() {
    app=$1 
    NS=$2 
    printf "\nApplication: $app\n"    
    GOPS=$(kubectl get application $app -n $NS -o yaml  2>/dev/null | 
                yq '.status.devfile' |
                yq '.metadata.attributes' |
                grep gitOpsRepository.url | 
                cut -d ' ' -f 2)       
    printf "\tGitops Repo: %s\n" "$GOPS"
    printf " "  

    COMPONENTS=$(kubectl get components -n $NS -o yaml) 
    LEN=$(echo "$COMPONENTS" | yq ".items[].metadata.name" | wc -l)  
    LEN=32
    for COMPONENT_INDEX in  $(eval echo {0..$LEN})
    do
        COMPONENT=$(echo "$COMPONENTS" | yq  ".items[$COMPONENT_INDEX]" -)  
        if [ "$COMPONENT" == "null" ] 
        then
            break
        fi
        APPNAME=$(echo "$COMPONENT" | yq  ".spec.application" -) 
        if [ $APPNAME == "$app" ] 
        then
            COMPONENT_NAME=$(echo "$COMPONENT" | yq  ".metadata.name" -) 
            REPO=$(echo "$COMPONENT" | yq  ".spec.source.git.url" -)
            IMG=$(echo "$COMPONENT" | yq '.spec.containerImage' -) 
            printf "\tComponent: %s\n\t\tGit: %s\n\t\tImage: %s\n" $COMPONENT_NAME  $REPO $IMG  
            
            RES=$(kubectl get GitOpsDeployment -l "appstudio.application.name=$app" -o yaml) 
            NM=$(echo "$RES" | yq  ".items[0].metadata.name" -) 
            REPO=$(echo "$RES" | yq  ".items[0].spec.source.repoURL" -)
            HEALTH=$(echo "$RES" | yq  '.items[0].status.health.status' -)
            DEST=$(echo "$RES" | yq  ".items[0].status.reconciledState.destination.namespace" -)  

            printf "\nGitOpsDeployment: %s\n\tGit: %s\n" $NM  $REPO   
            printf "\tHealth: %s Destination: %s\n" "$HEALTH" "$DEST"
            printf  "\tUse CLI for more info: %s \n"  "kubectl get GitOpsDeployment -l \"appstudio.application.name=$app\" -o yaml"

            RES=$(kubectl get snapshots -l  "appstudio.openshift.io/component=$COMPONENT_NAME" -o yaml) 
            NM=$(echo "$RES" | yq  ".items[0].metadata.name" -)  
            printf "\nSnapshots: %s\n" $NM  
            printf  "Use CLI for more info: %s \n"  "kubectl get snapshots -l  "appstudio.openshift.io/component=$COMPONENT_NAME" -o yaml"
    
            RES=$(kubectl get SnapshotEnvironmentBinding -l  "appstudio.application=$app" -o yaml) 
            NM=$(echo "$RES" | yq  ".items[0].metadata.name" -)  
            ENVIRONMENT=$(echo "$RES" | yq  ".items[0].spec.environment" -)  
            printf "\nSnapshotEnvironmentBinding: %s Environment: %s\n" $NM  $ENVIRONMENT
            printf  "Use CLI for more info: %s \n"  "kubectl get SnapshotEnvironmentBinding -l  "appstudio.application=$app" -o yaml"
        fi  
    done  
}
 
function showcurrentcontext {
    printf  "\nContext: %s NS: %s\n"  "$CURRENT_CONTEXT" "$NS" 
} 
  
# init and compute menu options
updateserverinfo   

./hack/create-environment.sh $NS dev

BANNER=banner 
MENU_TEXT=menu.txt  
PROMPT_DEMOS=""
SELECTED_DEMOS=""
seperator=""
let SCOUNTER=1
for ignored in ${DEMOS[@]}
do 
    PROMPT_DEMOS=$PROMPT_DEMOS$seperator${DEMOS[$SCOUNTER]}
    SELECTED_DEMOS=$SELECTED_DEMOS$seperator"false"
    seperator=";"
    let SCOUNTER++
done    
ALL_CONTEXTS=$(kubectl  config get-contexts -o name | xargs -n 1 echo -n ";" | tr -d " ")
ALL_CONTEXTS="${ALL_CONTEXTS:1}" 

until [ "${SELECT^}" == "q" ]; do
    clear 
    cat $BANNER
    showcurrentcontext
    printf "Select apps (space to select/deselect, a for all, n for none)\n\n" 
    prompt_for_multiselect result "$PROMPT_DEMOS" "$SELECTED_DEMOS" SELECT   
    # recompute selected next loop  
    SELECTED_DEMOS=${result// /;}  
    if [ "$SELECT" = "i" ]; then 
        clear 
        showcurrentcontext   
        let SCOUNTER=1
        for selected in $result
        do  
            if [ "$selected" = "true" ]; then  
                ./hack/e2e.sh demos/${DEMOS[$SCOUNTER]} 
            fi
            let SCOUNTER++
        done
        read -n1 -p "press key to continue: "  WAIT
    fi   
    #show all running, instead of selected ones
    if [ "$SELECT" = "s" ]; then  
        clear 
        echo "Applications" 
        showcurrentcontext      
        showallappstatus 
        showroutes $NS 
        read -n1 -p "press key to continue: "  WAIT
    fi 
    if [ "$SELECT" = "e" ]; then  
        clear 
        echo "Environments" 
        showResourceName Environments       
        read -n1 -p "press key to continue: "  WAIT
    fi 
    if [ "$SELECT" = "r" ]; then  
        clear  
        showroutes $NS 
        read -n1 -p "press key to continue: "  WAIT
    fi 
    if [ "$SELECT" = "q" ]; then  
        clear 
        cat $BANNER 
        echo 
        echo 
        exit
    fi 
    if [ "$SELECT" = "c" ]; then 
        clear  
        showcurrentcontext   
        ACTIVE_CONTEXTS="${ALL_CONTEXTS/$CURRENT_CONTEXT/true}"
        echo "Choose Context - x or enter to select, any other key to return"
        prompt_for_singleselect result "$ALL_CONTEXTS" "$ACTIVE_CONTEXTS" WHICHCONTEXT   
        clear
        if [ "$result" = "none" ]; then 
            echo 
            echo "No context selected"   
        else
            echo  
            kubectl config  use-context $result
            updateserverinfo
            read -n1 -p "press key to continue: "  WAIT
        fi 
    fi   
    if [ "$SELECT" = "p" ]; then
      WAIT="p"
      FULLPAGE=$(mktemp)
      LOOPCOUNT=0
      clear   
      echo "computing ..." 
      until [ "$WAIT" == "q" ]; do  
        ./hack/ls-builds.sh > $FULLPAGE
        let LOOPCOUNT++
        clear   
        showcurrentcontext   
        echo "Show all pipelines:", $(date)
        cat $FULLPAGE
        read -n1 -t 1 -p "$LOOPCOUNT: will continue looping, press q to stop ..."  WAIT 
        if [ "$WAIT" != "q" ]; then
          echo "$WAIT refreshing ..."
        fi
      done 
    fi 
    if [ "$SELECT" = "x" ]; then
        clear   
        printf  "\n\nWARNING WARNING WARNING"
        read -n1 -p "PRUNING COMPLETED PIPELINES PRESS y, other key to skip: "  WAIT
        echo 
        if [ "$WAIT" = "y" ]; then
          printf  "\n\nPRUNE COMPLETED PIPELINES \n\n" 
          ./hack/prune-completed-pipelines.sh 
          printf  "\n\nDONE \n\n" 
        fi  
        read -n1 -p "Press any key to continue ..."  WAIT
    fi 

      if [ "$SELECT" = "z" ]; then 
        clear 
        showcurrentcontext   
        let SCOUNTER=1
        echo "Selected Apps to Delete:"
        for selected in $result
        do  
            if [ "$selected" = "true" ]; then  
                echo ${DEMOS[$SCOUNTER]} 
            fi
            let SCOUNTER++
        done
        read -n1 -p "Deleting above Applications!!! PRESS y, other key to skip: "  WAIT
        echo
        if [ "$WAIT" = "y" ]; then
          let SCOUNTER=1
          for selected in $result
          do  
              if [ "$selected" = "true" ]; then  
                  kubectl delete application ${DEMOS[$SCOUNTER]} -n $NS
              fi
              let SCOUNTER++
          done
          read -n1 -p "press key to continue: "  WAIT
        fi
      fi      

done 

