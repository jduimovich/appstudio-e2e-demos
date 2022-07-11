#!/usr/bin/env bash
declare -A DEMOS
COUNTER=0
for dir in demos/*
do
   if [ -d $dir ]; then    
      let COUNTER++  
      DEMOS["$COUNTER"]=$(basename $dir)
   fi
done
echo "$COUNTER demos found."  
readarray -t sorted < <(for a in "${!DEMOS[@]}"; do echo "$a"; done | sort)

#
function updateserverinfo() {
    export WHICH_SERVER=$(oc whoami)
    export APP_STUDIO=$(echo "$WHICH_SERVER" | grep  "appstudio-") 
    if [ -n "$APP_STUDIO" ]
    then
        export APP_STUDIO_NS=$(oc project --short)
        export MODE="\napp-studio mode will use namespace $APP_STUDIO_NS.\n"
    else
        export MODE="\nDirect cluster mode will create a new namespace per project.\n"
        export  APP_STUDIO_NS="error"
    fi
    export  CONTEXT=$(oc config current-context)
}

updateserverinfo 

BUNDLE=default   
BANNER=banner
SHOWSTATUS=no
TRIGGER_BUILDS=no
CHOICE=
until [ "${CHOICE^}" != "" ]; do
    echo -n 
    clear
    cat $BANNER
    printf "$MODE" 
   
    if [ "$TRIGGER_BUILDS" = "yes" ]; then
        TRIGGER_BUILDS=no 
        if [ -n "$APP_STUDIO" ]
        then 
            # one namespace, so build all in that one only
            ./hack/build-all.sh $APP_STUDIO_NS
        else
            # many namespaces, build all in each 
            for key in $(seq $COUNTER)
            do   
                ./hack/build-all.sh ${DEMOS[$key]} 
                #read -n1 -p "Press any key to continue ..."  WAIT
            done
        fi 
       
    fi
    if [ "$SHOWSTATUS" = "yes" ]; then
        SHOWSTATUS=no
        echo "--------------------------------"
        echo "STATUS " 
        for key in $(seq $COUNTER)
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
    IDX=1
    HALF=$(echo "$COUNTER / 2"  | bc)
    TWOX=$(echo "$HALF * 2"  | bc)
    for key in $(seq $HALF)
    do
        k2=$(echo "$key + $HALF" | bc)
        printf "%3s: %-30s\t%3s: %-30s\n"  $key  ${DEMOS[$key]} $k2 ${DEMOS[$k2]}
    done
    if [ "$TWOX" != "$COUNTER" ]; then 
        printf "%3s: %-30s\n"  $COUNTER  ${DEMOS[$COUNTER]}
    fi

    printf "Commands available: \n(q to quit, s for status, p (show pipelines), t trigger  webhooks)\n"
    printf "(a install-all, b toggle-banner, h (hacbs bundle), d (default bundle) )\n"
    printf "(c switch to appstudio context, l switch to local-crc context)\n"
    printf  "%s\n" "Build Pipelines: $BUNDLE"
    printf  "%s\n" "Current Context: $CONTEXT"

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
    if [ "$SELECT" = "c" ]; then 
        echo 
        echo "Switching to context called appstudio."
        echo "This is your list, if appstudio is missing, go read the onboarding doc"
        kubectl config get-contexts
        echo "running oc config  use-context appstudio"
        oc config  use-context appstudio
        updateserverinfo
        read -n1 -p "press key to continue: "  WAIT
    fi 
    if [ "$SELECT" = "l" ]; then 
        echo 
        echo "Switching to context for local CRC"
        echo "This is your list, if appstudio is missing, go read the onboarding doc"
        kubectl config get-contexts  
        echo "running oc config  use-context  default/api-crc-testing:6443/kubeadmin"
        oc config  use-context  "crc-admin"
        updateserverinfo
        read -n1 -p "press key to continue: "  WAIT
    fi 
    if [ "$SELECT" = "s" ]; then
        SHOWSTATUS=yes 
    fi
    if [ "$SELECT" = "t" ]; then
        TRIGGER_BUILDS=yes 
    fi
    if [ "$SELECT" = "p" ]; then
        echo
        echo "Show all pipelines"
        ./hack/ls-builds.sh 
        read -n1 -p "Press any key to continue ..."  WAIT
    fi
    if [ "$SELECT" = "a" ]; then 
        echo; echo "Run All" 
        for key in $(seq $COUNTER)
        do   
            ./hack/e2e.sh demos/${DEMOS[$key]} $BUNDLE
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