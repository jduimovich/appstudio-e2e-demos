#!/bin/bash
SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

export CURRENT_CONTEXT=$(kubectl config current-context)  
if [ "$(oc auth can-i '*' '*' --all-namespaces)" == "yes" ]; then  
        #echo "Running private version of App Studio using personal user for Quay"  
        NS=aaaa-studio
        USE_REDHAT_QUAY=false 
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
        AGGRESSIVE_PRUNE_PIPELINES=true
else 
        #echo  "Assume AppStudio/Stonesoup managed mode and using RH Quay"
        NS=$(oc project --short)  
        USE_REDHAT_QUAY=true  
        AGGRESSIVE_PRUNE_PIPELINES=true
fi

if [ "$USE_REDHAT_QUAY" == "false" ]; then 
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