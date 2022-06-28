
#!/bin/bash

QUERY=$(oc get pipelineruns -o yaml)
for prindex in {0..100}
do   
    PR=$(echo "$QUERY"  | yq e '.items['$prindex']')  
    if [  "$PR" != "null" ]
        then     
        BUILD=$(echo "$PR"  | yq e '.metadata.name')  
        message=$(echo "$PR"  | yq e '.status.conditions[0].message')  
        IMG=$(echo "$PR"  | yq e '.spec.params[1].value') 
        echo "$prindex: $BUILD"
        echo " $IMG"  
        echo " $message"  
        echo 
    else  
         break
    fi 
done
 
exit

STATUS=$(oc get pr $1 -o jsonpath='{.status.conditions[0].status}') 
if [ "$STATUS" = "False" ]; then 
   printf "\nBuild %20s Failed\n" "$1"   
            exit 1
fi 

print_formatted_status () {
   BUILDNAME=$1
   LABEL=$2
   JSONPATH=$3
   FIELD=$4
   ESCAPED=$(echo "$FIELD" | sed 's/\./\\./g') 

   VALUE=$(oc get pr $BUILDNAME -o jsonpath="{$JSONPATH.$ESCAPED}") 
   if [ -z "$VALUE" ]
   then
      VALUE='(not-set)'
   fi 
   printf " %-20s : %s\n" "$LABEL" "$VALUE"
}
 
printf "\nBuild %20s\n" "$1"  
print_formatted_status $1 "Status"     ".status.conditions[0]" "status"
print_formatted_status $1 "Message"     ".status.conditions[0]" "message"
print_formatted_status $1 "IsBuild"    ".metadata.annotations" "build.appstudio.openshift.io/build"
print_formatted_status $1 "Type"       ".metadata.annotations" "build.appstudio.openshift.io/type"
print_formatted_status $1 "Version"    ".metadata.annotations" "build.appstudio.openshift.io/version"
print_formatted_status $1 "Repo"       ".metadata.annotations" "build.appstudio.openshift.io/repo" 
print_formatted_status $1 "Image"      ".metadata.annotations" "build.appstudio.openshift.io/image"
print_formatted_status $1 "Manifest"   ".metadata.annotations" "build.appstudio.openshift.io/deploy"
 