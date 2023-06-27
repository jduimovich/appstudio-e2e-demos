#!/bin/bash
SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

export CURRENT_CONTEXT=$(kubectl config current-context)  
if [ "$(oc auth can-i '*' '*' --all-namespaces)" == "yes" ]; then  
        #echo "Running private version of App Studio using personal user for Quay"  
        NS=user1-tenant 
        kubectl get ns $NS &> /dev/null
        ERR=$? 
        if [  "$ERR" != "0" ]
        then 
                $SCRIPTDIR/create-ns.sh $NS 
        else  
                CURRENT_NS=$(oc project --short)  
                if [ "$CURRENT_NS" != "$NS" ]; then 
                        oc project $NS
                fi
        fi
        AGGRESSIVE_PRUNE_PIPELINES=false
        if [ -z "$MY_QUAY_USER" ]
        then
                echo Warning: missing env MY_QUAY_USER 
        fi
        if [ -z "$MY_QUAY_TOKEN" ]
        then
                echo Warning: missing env MY_QUAY_TOKEN   
        fi
else 
        #echo  "Assume AppStudio/Stonesoup managed mode and using RH Quay"
        NS=$(oc project --short)   
        AGGRESSIVE_PRUNE_PIPELINES=false
fi
 