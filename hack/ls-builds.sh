
#!/bin/bash   
SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"


B=$(mktemp)
M=$(mktemp)
R=$(mktemp) 
function printPR() {  
COUNTER=0 
for prindex in {0..100}
do   
    PR=$(echo "$1"  | yq e '.items['$prindex']')  
    if [  "$PR" != "null" ]
    then 
        status=$(echo "$PR"  | yq e '.status.conditions[0].status')   
        if [ "$2" = "$status" ] 
        then
                if [ $COUNTER == 0 ] ; then echo $3; fi
                let COUNTER++
                echo "$PR"  | yq e '.metadata.name' > $B &
                echo "$PR"  | yq e '.status.conditions[0].message' > $M &
                echo "$PR"  | yq e '.spec.params[1].value' > $R &
                wait
                build=$(< $B)  
                message=$(< $M)  
                img=$(< $R) 
                wait
                echo "$COUNTER: $build $status"
                echo " $img"  
                echo " $message"  
                echo
         fi
    else   
         break
    fi 
done    
if [ $COUNTER != 0 ] 
then
    echo "$COUNTER Pipelines in $3 state"
    echo "----------------------------------------------" 
fi
}

source $SCRIPTDIR/select-ns.sh default     
QUERY=$(kubectl get pipelineruns -o yaml -n "$NS")
 
printPR "$QUERY" "Unknown"  "Running" 
printPR "$QUERY" "True" "Completed:"   
printPR "$QUERY" "False" "Failed" 
printPR "$QUERY" "null"  "Missing Status" 

 