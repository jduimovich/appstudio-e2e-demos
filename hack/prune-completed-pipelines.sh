
#!/bin/bash   
SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

function prune_pipeline_run_with_status() { 

COUNTER=0
RESULTS="$COUNTER Pipelines with status $2 Deleted" 
for prindex in {0..100}
do   
    PR=$(echo "$1"  | yq e '.items['$prindex']')   
    if [  "$PR" != "null" ]
    then 
        status=$(echo "$PR"  | yq e '.status.conditions[0].status')   
        if [ "$2" = "$status" ] 
        then
            let COUNTER++
            RESULTS="$COUNTER Pipelines with status $2 Deleted" 
            mkdir -p ./hack/logs/deleted-prs 
            PRNAME=$(echo "$PR"  | yq e '.metadata.name')
            echo $PR > ./hack/logs/deleted-prs/$PRNAME
            kubectl delete pipelineruns $PRNAME -n "$NS" 
         fi
    else   
         break
    fi 
done    
echo $RESULTS
}

source $SCRIPTDIR/select-ns.sh default     
QUERY=$(kubectl get pipelineruns -o yaml -n "$NS") 
echo "Deleting Completed. Failed and Unknown" 
prune_pipeline_run_with_status "$QUERY" "True"  
prune_pipeline_run_with_status "$QUERY" "False"  
prune_pipeline_run_with_status "$QUERY" "null"   
 