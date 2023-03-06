 
NS=$1
if [ -z "$NS" ]
then
      echo "Usage app-name namespace"  
      exit -1 
fi


function showdeployments() { 
    echo  
    NS=$1    
    RESOURCES=$(kubectl get GitOpsDeployment -n $NS -o yaml) 
    LEN=$(echo "$RESOURCES" | yq .items | yq length)  
    echo "$LEN GitOpsDeployments found."
    let LEN--
    for RES_INDEX in  $(eval echo {0..$LEN}) 
    do 
        RESOURCE=$(echo "$RESOURCES" | yq  ".items[$RES_INDEX]" -) 
        NM=$(echo "$RESOURCE" | yq  ".metadata.name" - ) 
        REPO=$(echo "$RESOURCE" | yq  ".spec.source.repoURL" -)
        STATUS=$(echo "$RESOURCE" | yq  '.status.health.status' -)
        DESTNS=$(echo "$RESOURCE" | yq  ".status.reconciledState.destination.namespace" -)
        echo " Name: $NM"
        echo " Repo: $REPO" 
        echo " Namespace: $DESTNS Status: $STATUS"
        echo 
    done 
     
    RESOURCES=$(kubectl get snapshots -n $NS -o yaml) 
    LEN=$(echo "$RESOURCES" | yq .items | yq length)  
    echo "$LEN Snapshots found."
    let LEN--
    for RES_INDEX in  $(eval echo {0..$LEN}) 
    do   
        RESOURCE=$(echo "$RESOURCES" | yq  ".items[$RES_INDEX]" -)
        NM=$(echo "$RESOURCE" | yq  ".metadata.name" - ) 
        echo "   $NM " 
    done 
    echo 
      
    RESOURCES=$(kubectl get  SnapshotEnvironmentBinding -n $NS -o yaml) 
    LEN=$(echo "$RESOURCES" | yq .items | yq length)
    echo "$LEN SnapshotEnvironmentBinding found." 
    let LEN--
    for RES_INDEX in  $(eval echo {0..$LEN}) 
    do   
        RESOURCE=$(echo "$RESOURCES" | yq  ".items[$RES_INDEX]" -)
        NM=$(echo "$RESOURCE" | yq  ".metadata.name" - )
        ENVIRONMENT=$(echo "$RESOURCE" | yq  ".spec.environment" -) 
        SNAP=$(echo "$RESOURCE" | yq  ".spec.snapshot" -) 
        echo "   $NM Snapshot: $SNAP Environment: $ENVIRONMENT" 
    done   
}



showdeployments $NS