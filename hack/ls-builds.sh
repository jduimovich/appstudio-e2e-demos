
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
else
        export DIRS=$(ls demos/) 
fi

for ns in $DIRS 
do
   QUERY=$(oc get pipelineruns -o yaml -n $ns)
   echo "Running in $ns ... "
   printPR "$QUERY" "Unknown"  
   echo "----------------------------------------------" 
   echo  
   echo "Completed in $ns ... "
   printPR "$QUERY" "True"   
   echo "----------------------------------------------" 
   echo  
   echo "Failed in $ns ... "
   printPR "$QUERY" "False"   
   echo "----------------------------------------------" 
   echo  
done

          