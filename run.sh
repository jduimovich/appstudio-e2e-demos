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
 
SHOWSTATUS=no
TRIGGER_BUILDS=no
CHOICE=
until [ "${CHOICE^}" != "" ]; do
    echo -n 
    clear
    cat banner
   
    if [ "$TRIGGER_BUILDS" = "yes" ]; then
        TRIGGER_BUILDS=no 
        for key in ${!sorted[@]} 
        do
            oc project ${DEMOS[$key]}
            ./hack/build-all.sh
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
                printf "\n${DEMOS[$key]}\n " 
                oc get application ${DEMOS[$key]}  -n ${DEMOS[$key]} -o yaml | \
                     yq '.status.devfile' | \
                     yq '.metadata.attributes' |
                     grep gitOpsRepository.url   
                oc get routes -n ${DEMOS[$key]}  -o yaml  2>/dev/null | 
                    yq '.items[].spec.host | select(. != "el*")' |  
                    xargs -n 1 printf " Route: https://%s\n"
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
    read -n1 -p "Choose Demo (q to quit, s for status): "  SELECT 
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