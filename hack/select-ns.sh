

export CURRENT_CONTEXT=$(kubectl config current-context)  
if [ "$(oc auth can-i '*' '*' --all-namespaces)" == "yes" ]; then  
        #echo "Running private version of App Studio using personal user for Quay"  
        NS=personal-backend   
        USE_REDHAT_QUAY=false 
        kubectl get ns $NS &> /dev/null
        ERR=$? 
        if [  "$ERR" != "0" ]
        then 
                echo $ERR
                oc new-project $NS
        fi 
else 
        #echo  "Assume AppStudio/Stonesoup managed mode and using RH Quay"
        NS=$(oc project --short)  
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