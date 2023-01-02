

export CURRENT_CONTEXT=$(kubectl config current-context)  
if [ "$(oc auth can-i '*' '*' --all-namespaces)" == "yes" ]; then 
        echo "Full Control of this cluster, CRC or private cluster assumed"
        echo "Running private version of App Studio using personal user for Quay" 
        
        NS=rockbroth 
        SINGLE_NAMESPACE_MODE=true
        SINGLE_NAMESPACE=$NS 
        USE_REDHAT_QUAY=false 
        kubectl get ns $NS &> /dev/null
        ERR=$? 
        if [  "$ERR" == "0" ]
        then
                echo "Namespace $NS  exists"
        else
                oc new-project $NS
        fi 
else
        echo "Limited Control of this cluster, assume AppStudio/Stonesoup managed mode"
        echo  "Single namespace and using RH Quay"
        NS=$(oc project --short)
        SINGLE_NAMESPACE_MODE=true
        SINGLE_NAMESPACE=$NS
        USE_REDHAT_QUAY=true  
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

    
echo "SINGLE_NAMESPACE_MODE=$SINGLE_NAMESPACE_MODE"
echo "SINGLE_NAMESPACE=$NS"
echo "NS=$NS"
echo "WORKSPACE=$WORKSPACE"
 