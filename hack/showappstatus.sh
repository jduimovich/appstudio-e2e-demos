
APP=$1
if [ -z "$APP" ]
then
      echo "Usage app-name namespace"  
      exit -1 
fi
NS=$2
if [ -z "$NS" ]
then
      echo "Usage app-name namespace"  
      exit -1 
fi


function showappstatus() {
    app=$1 
    NS=$2 
    printf "\nApplication: $app\n"    
    GOPS=$(kubectl get application $app -n $NS -o yaml  2>/dev/null | 
                yq '.status.devfile' |
                yq '.metadata.attributes' |
                grep gitOpsRepository.url | 
                cut -d ' ' -f 2)       
    printf "\tGitops Repo: %s\n" "$GOPS"
    printf " "  

    COMPONENTS=$(kubectl get components -n $NS -o yaml) 
    LEN=$(echo "$COMPONENTS" |  yq length)  
    let LEN--   
    for COMPONENT_INDEX in  $(eval echo {0..$LEN})
    do
        COMPONENT=$(echo "$COMPONENTS" | yq  ".items[$COMPONENT_INDEX]" -)  
        if [ "$COMPONENT" == "null" ] 
        then
            break
        fi
        APPNAME=$(echo "$COMPONENT" | yq  ".spec.application" -) 
        if [ $APPNAME == "$app" ] 
        then
            COMPONENT_NAME=$(echo "$COMPONENT" | yq  ".metadata.name" -) 
            REPO=$(echo "$COMPONENT" | yq  ".spec.source.git.url" -)
            IMG=$(echo "$COMPONENT" | yq '.spec.containerImage' -) 
            printf "\tComponent: %s\n\t\tGit: %s\n\t\tImage: %s\n" $COMPONENT_NAME  $REPO $IMG  
           
        fi  
    done      
}
 
showappstatus $APP $NS