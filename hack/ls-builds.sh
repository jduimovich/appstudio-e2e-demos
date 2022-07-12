
#!/bin/bash   

B=$(mktemp)
M=$(mktemp)
R=$(mktemp)
COUNTER=0
function printPR() {   
for prindex in {0..100}
do   
    PR=$(echo "$1"  | yq e '.items['$prindex']')  
    if [  "$PR" != "null" ]
    then 
        status=$(echo "$PR"  | yq e '.status.conditions[0].status')  
        if [ "$2" = "$status" ] 
        then
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
}

export APP_STUDIO=$(oc whoami | grep  "appstudio-") 
if [ -n "$APP_STUDIO" ]
then
    export DIRS=$(oc project --short)  
fi 
ALL_NS="--all-namespaces"
if [ -n "$APP_STUDIO" ]
then
    ALL_NS="-n $DIRS" 
fi  
QUERY=$(oc get pipelineruns -o yaml  $ALL_NS)

echo "Running: "
COUNTER=0
printPR "$QUERY" "Unknown"  
echo "$COUNTER Pipelines actively Running"
echo "----------------------------------------------" 
echo  

echo "Completed:"
COUNTER=0
printPR "$QUERY" "True"
echo "$COUNTER Completed Pipelines"
echo "----------------------------------------------" 
echo 

echo "Failed:"
COUNTER=0
printPR "$QUERY" "False"
echo "$COUNTER Failed Pipelines"
echo "----------------------------------------------" 
echo

 