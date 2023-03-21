#!/usr/bin/env bash

DEMO_DIR_INDEX=1
ALL_DEMOS=$(cat demo-dirs)
DEMO_COUNT=$(echo "$ALL_DEMOS" | wc -w | cut -d ' ' -f 1) 
let DEMO_COUNT++
DEMO_DIR=demos

function nextDemosDir() { 
    let DEMO_DIR_INDEX++
    if [ $DEMO_DIR_INDEX == $DEMO_COUNT ]; then
        DEMO_DIR_INDEX=1
    fi
    initDemoList
}
declare -A DEMOS  
function initDemoList() { 
    DEMOS=()
    DEMO_DIR=$(echo $ALL_DEMOS | cut -d ' ' -f $DEMO_DIR_INDEX)
    COUNTER=0
    for dir in $DEMO_DIR/*
    do
    if [ -d $dir ]; then    
        let COUNTER++  
        DEMOS["$COUNTER"]=$(basename $dir) 
    fi
    done
    echo "$COUNTER demos found."  
    source ./hack/config.sh  
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
}
 
# utilities (verbose) for menus, keep separate.
source hack/utils-for-menu.sh

# set env vars for various options, kcp,crc,appstudio-pre-kcp
function updateserverinfo() {
    source ./hack/select-ns.sh default  
}  
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

function showdeployments() { 
    ./hack/showdeployments.sh $1
}
function showallappstatus() {
    ALL_APPS=$(kubectl get  application.appstudio.redhat.com -o yaml -n $NS | yq '.items[].metadata.name' | xargs -n1 echo -n " " )
    echo 
    HAS_APPS=false
    for app in $ALL_APPS
    do   
        HAS_APPS=true
        showappstatus $app $NS
    done  
    if [ "$HAS_APPS" == "true" ]
    then
        showdeployments $NS 
        showroutes $NS 
    else  
        printf "\nNo Applications found in $NS:\n\n" 
    fi
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
    ./hack/showappstatus.sh $1 $2
} 
 
function showcurrentcontext {
    printf  "\nContext: %s NS: %s Quick-Build: %s\n"  "$CURRENT_CONTEXT" "$NS" "$QUICK_PIPELINES"
} 
  
# init and compute menu options
initDemoList
updateserverinfo    
./hack/create-environment.sh $NS Development

BANNER=banner 
MENU_TEXT=text-menu.txt  
ALL_CONTEXTS=$(kubectl  config get-contexts -o name | xargs -n 1 echo -n ";" | tr -d " ")
ALL_CONTEXTS="${ALL_CONTEXTS:1}"  

until [ "${SELECT^}" == "q" ]; do
    clear 
    cat $BANNER
    if [ -f $DEMO_DIR/info ];
    then
        cat $DEMO_DIR/info
    fi 
    showcurrentcontext
    printf "Select apps (space to select/deselect, a for all, n for none)\n\n" 
    prompt_for_multiselect result "$PROMPT_DEMOS" "$SELECTED_DEMOS" SELECT   
    # recompute selected next loop  
    SELECTED_DEMOS=${result// /;}  
    if [ "$SELECT" = "i" ]; then 
        clear 
        showcurrentcontext 
        NO_APPS_INSTALLED_MSG="No Apps Selected to install"  
        let SCOUNTER=1
        for selected in $result
        do  
            if [ "$selected" = "true" ]; then
                NO_APPS_INSTALLED_MSG=""
                APPNAME=${DEMOS[$SCOUNTER]}
                INSTALL_LOG="$LOG_DIR/$APPNAME.txt"
                echo "Install log in: $INSTALL_LOG"
                ./hack/background.sh e2e.sh "$DEMO_DIR/$APPNAME" "$INSTALL_LOG"  
            fi
            let SCOUNTER++
        done 
        echo $NO_APPS_INSTALLED_MSG
        read -n1 -p "press key to continue: "  WAIT
    fi   
    #show all running, instead of selected ones
    if [ "$SELECT" = "s" ]; then  
        clear 
        echo "Applications" 
        showcurrentcontext      
        showallappstatus 
        read -n1 -p "press key to continue: "  WAIT
    fi 
    if [ "$SELECT" = "e" ]; then  
        clear 
        echo "Environments" 
        showResourceName Environments       
        read -n1 -p "press key to continue: "  WAIT
    fi
    if [ "$SELECT" = "f" ]; then  
        clear 
        nextDemosDir
        initDemoList       
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
            if [ "$AGGRESSIVE_PRUNE_PIPELINES" == "true" ] 
            then
                echo 
                echo "Due to PVC Limits, this demo driver agressively removes pipelines"
                ./hack/prune-completed-pipelines.sh   
            fi
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
    if [ "$SELECT" = "A" ]; then
        clear   
        printf  "\n\nInstalling Auto-builder"  
        bash ./hack/rebuilder/install-rebuilder  
        echo 
        read -n1 -p "Press any key to continue ..."  WAIT
    fi  
    if [ "$SELECT" = "D" ]; then
        clear   
        printf  "\n\nDelete Auto-builder"  
        bash ./hack/rebuilder/delete-rebuilder  
        echo 
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
    if [ "$SELECT" == "b" ] || [ "$SELECT" == "B" ]; then 
        clear 
        showcurrentcontext    
        let SCOUNTER=1 
        for selected in $result
        do  
            if [ "$selected" == "true" ] || [ "$SELECT" == "B" ]; then  
                ./hack/rebuild-app.sh  ${DEMOS[$SCOUNTER]}  $NS
            else 
                echo Skip  ${DEMOS[$SCOUNTER]} 
            fi
            let SCOUNTER++
        done 
        read -n1 -p "press key to continue: "  WAIT
    fi   
done 

