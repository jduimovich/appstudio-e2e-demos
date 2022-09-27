WHICH_SERVER=$(oc whoami)
APP_STUDIO=$(echo "$WHICH_SERVER" | grep  "appstudio-")
echo "whoami: $WHICH_SERVER" 
SINGLE_NAMESPACE_MODE=false
SINGLE_NAMESPACE= 
if [ -n "$APP_STUDIO" ]
then
        echo Running in App Studio
        NS=$(oc project --short)
        SINGLE_NAMESPACE_MODE=true
        SINGLE_NAMESPACE=$NS
else
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

echo "SINGLE_NAMESPACE_MODE=$SINGLE_NAMESPACE_MODE"
echo "SINGLE_NAMESPACE=$NS"
echo "NS=$NS"
