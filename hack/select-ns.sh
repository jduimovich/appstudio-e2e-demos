
# quick hack, pass anything and KCP mode is false.
# $1 is for the legacy namespace and $2 is to deselect kcp
kubectl get ws  >/dev/null 2>&1
ERR=$?  
if [ $ERR  == 0 ]
then
        echo "KCP Mode"
        KCP_MODE=true 
else 
        echo "Direct Cluster Mode (not-kcp)" 
        KCP_MODE=false  
fi 
export CURRENT_CONTEXT=$(kubectl config current-context) 
if [ "$KCP_MODE" == "true" ]
then 
# App Studio so that the names for components are set to redhat server, change flags later
        APP_STUDIO=
        USE_REDHAT_QUAY=true
        NS=default
        SINGLE_NAMESPACE_MODE=true 
        SINGLE_NAMESPACE=$NS 
        kubectl ws
        kubectl ws appstudio
        WORKSPACE=$(kubectl ws . --short)
else
        WHICH_SERVER=$(oc whoami)
        APP_STUDIO=$(echo "$WHICH_SERVER" | grep  "appstudio-")
        SINGLE_NAMESPACE_MODE=false
        SINGLE_NAMESPACE=  
        WORKSPACE="(not-kcp)"
        if [ -n "$APP_STUDIO" ]
        then
                echo Running in App Studio
                NS=$(oc project --short)
                SINGLE_NAMESPACE_MODE=true
                SINGLE_NAMESPACE=$NS
                USE_REDHAT_QUAY=true
        else
                USE_REDHAT_QUAY=false
                # CRC wit HAC or not
                oc get ns boot  >/dev/null 2>&1
                ERR=$?  
                if [ $ERR  == 0 ]
                then
                        echo "Boot Namespace exists, HAC present, single namespace mode"
                        NS=$(oc project --short)
                        SINGLE_NAMESPACE_MODE=true
                        SINGLE_NAMESPACE=$NS
                else 
                        echo "Standalone CRC, No HAC 1 namespace per project"
                        NS=$1   
                        SINGLE_NAMESPACE_MODE=false
                        SINGLE_NAMESPACE=
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
        fi  
fi   
echo "SINGLE_NAMESPACE_MODE=$SINGLE_NAMESPACE_MODE"
echo "SINGLE_NAMESPACE=$NS"
echo "NS=$NS"
echo "WORKSPACE=$WORKSPACE"
 