#!/bin/bash 
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

BANNER=banner
SHOWSTATUS=no
TRIGGER_BUILDS=no
CHOICE=
until [ "${CHOICE^}" != "" ]; do
    echo -n 
    clear
    cat $BANNER
   
    if [ "$TRIGGER_BUILDS" = "yes" ]; then
        TRIGGER_BUILDS=no 
        for key in ${!sorted[@]} 
        do 
            ./hack/build-all.sh ${DEMOS[$key]}
            #read -n1 -p "Press any key to continue ..."  WAIT
        done
    fi
    if [ "$SHOWSTATUS" = "yes" ]; then
        SHOWSTATUS=no
        echo "--------------------------------"
        echo "STATUS "
        for key in ${!sorted[@]} 
        do   
            kubectl get Application ${DEMOS[$key]} -n ${DEMOS[$key]} &> /dev/null
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
                GOPS=$(oc get application ${DEMOS[$key]}  -n ${DEMOS[$key]} -o yaml | \
                     yq '.status.devfile' | \
                     yq '.metadata.attributes' |
                     grep gitOpsRepository.url | 
                     cut -d ' ' -f 2)   
                printf "\tGitops Repo: %s\n" "$GOPS"
                oc get routes -n ${DEMOS[$key]}  -o yaml  2>/dev/null | 
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
    echo "Commands available: (q to quit, s for status, t to build all via triggers)"
    read -n1 -p "Choose Demo or Command: "  SELECT 
    if [ "$SELECT" = "d"   ]; then 
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
    SELECT=${SELECT^} 
    CHOICE=${DEMOS[$SELECT]}
    if [ -n "$CHOICE" ]; then
        echo; echo "Demo chosen is $CHOICE"
        ./hack/e2e.sh demos/$CHOICE
        CHOICE=""
        read -n1 -p "Press any key to continue ..."  WAIT
    else      
        clear
        cat banner
    fi 
    echo;
done  