#!/usr/bin/env bash
declare -A DEMOS
COUNTER=0
for dir in demos/*
do
   if [ -d $dir ]; then   
      DEMOS["$COUNTER"]=$(basename $dir) 
      let COUNTER++  
   fi
done
echo "$COUNTER demos found."  
readarray -t sorted < <(for a in "${!DEMOS[@]}"; do echo "$a"; done | sort)

WHICH_SERVER=$(oc whoami)
APP_STUDIO=$(echo "$WHICH_SERVER" | grep  "appstudio-") 
if [ -n "$APP_STUDIO" ]
then
 MODE="Note, this demo running against an app-studio so will use the current namespace only."
 APP_STUDIO_NS=$(oc project --short)
else
 MODE="This demo running outside app studio, will create a new namespace per project"
 APP_STUDIO_NS="error"
fi

BUNDLE=default   
BANNER=banner
SHOWSTATUS=no
TRIGGER_BUILDS=no
CHOICE=
until [ "${CHOICE^}" != "" ]; do
    echo -n 
    clear
    cat $BANNER
    echo "$MODE" 
   
    if [ "$TRIGGER_BUILDS" = "yes" ]; then
        TRIGGER_BUILDS=no 
        for key in ${!sorted[@]} 
        do 
        if [ -n "$APP_STUDIO" ]
            then
                NS=$APP_STUDIO_NS
            else
                NS=${DEMOS[$key]} 
            fi 
            ./hack/build-all.sh $NS
            #read -n1 -p "Press any key to continue ..."  WAIT
        done
    fi
    if [ "$SHOWSTATUS" = "yes" ]; then
        SHOWSTATUS=no
        echo "--------------------------------"
        echo "STATUS "
        for key in ${!sorted[@]} 
        do  
            if [ -n "$APP_STUDIO" ]
            then
                NS=$APP_STUDIO_NS
            else
                NS=${DEMOS[$key]} 
            fi 
            kubectl get Application ${DEMOS[$key]} -n $NS &> /dev/null
            ERR=$? 
            if [  "$ERR" == "0" ]
            then
                printf "\nApplication: ${DEMOS[$key]}\n" 
                for c in demos/${DEMOS[$key]}/components/*
                do 
                   NM=$(yq '.metadata.name' $c)
                   REPO=$(yq '.spec.source.git.url' $c)
                   printf "\tComponent: %s @ %s\n" $NM $REPO
                done
                if [ -n "$APP_STUDIO" ]
                then
                    NS=$APP_STUDIO_NS
                else
                    NS=${DEMOS[$key]} 
                fi  
                GOPS=$(oc get application ${DEMOS[$key]}  -n $NS -o yaml | \
                     yq '.status.devfile' | \
                     yq '.metadata.attributes' |
                     grep gitOpsRepository.url | 
                     cut -d ' ' -f 2)   
                CONF=$(oc get configmap build-pipelines-defaults -n $NS -o yaml 2>/dev/null | yq '.data') 
                if [ "$CONF" = "null" ]; then
                    CONF=default 
                fi
                printf "\tPipelines Bundle: $CONF\n"
                printf "\tGitops Repo: %s\n" "$GOPS"
                oc get routes -n $NS  -o yaml  2>/dev/null | 
                    yq '.items[].spec.host | select(. != "el*")' |  
                    xargs -n 1 printf "\tRoute: https://%s\n"
                printf " "

            else 
                printf "\n${DEMOS[$key]} not running\n"
            fi 
        done  
    fi 
    echo "--------------------------------"
    for key in ${!sorted[@]} 
    do  
        printf "%3s: %-20s \n"  $key  ${DEMOS[$key]}
    done
    printf "Commands available: \n(q to quit, s for status, t trigger all webhooks)\n"
    printf "(a install-all, b toggle-banner, h (hacbs bundle), d (default bundle) )\n"
    printf  "%s\n" "Build Pipelines: $BUNDLE"
    read -n1 -p "Choose Demo or Command: "  SELECT 
    if [ "$SELECT" = "b"   ]; then 
        if [ "$BANNER" = "banner"   ]; then 
            BANNER=alpo-studio
        else 
            BANNER=banner
        fi
    fi 
    if [ "$SELECT" = "q" ]; then 
        echo 
        echo "Exiting..."
        exit
    fi 
    if [ "$SELECT" = "s" ]; then
        SHOWSTATUS=yes 
    fi
    if [ "$SELECT" = "t" ]; then
        TRIGGER_BUILDS=yes 
    fi
    if [ "$SELECT" = "a" ]; then 
        echo; echo "Run All"
        for run in ${!sorted[@]} 
        do   
            ./hack/e2e.sh demos/${DEMOS[$run]} $BUNDLE
        done 
    fi
    if [ "$SELECT" = "h" ]; then 
        echo; echo "Configure all new projects to use the HACBS Repos"
        BUNDLE=hacbs
    fi
  if [ "$SELECT" = "d" ]; then 
        echo; echo "Configure all new projects to use the default bundle"
        BUNDLE=default       
    fi
    SELECT=${SELECT^} 
    CHOICE=${DEMOS[$SELECT]}
    if [ -n "$CHOICE" ]; then
        echo; echo "Demo chosen is $CHOICE"
        ./hack/e2e.sh demos/$CHOICE $BUNDLE 
        CHOICE=""
        read -n1 -p "Press any key to continue ..."  WAIT
    else      
        clear
        cat banner
    fi 
    echo;
done  