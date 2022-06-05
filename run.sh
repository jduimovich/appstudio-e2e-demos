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
 
SHOWSTATUS=
CHOICE=
until [ "${CHOICE^}" != "" ]; do
    echo -n 
    clear
    cat banner
   
    if [ "$SHOWSTATUS" = "yes" ]; then
        SHOWSTATUS=no
        echo "--------------------------------"
        echo "STATUS "
        kubectl get Application ${DEMOS[$key]} -n ${DEMOS[$key]} &> /dev/null
        ERR=$? 
        if [  "$ERR" == "0" ]
        then
            RT=$(oc get routes ${DEMOS[$key]} -n ${DEMOS[$key]}  -o yaml  2>/dev/null | yq '.spec.host')
            printf " (Installed)  Running at https://$RT\n" 
        else 
            printf "${DEMOS[$key]} not running\n"
        fi 
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
    SELECT=${SELECT^} 
    CHOICE=${DEMOS[$SELECT]}
    if [ -n "$CHOICE" ]; then
        echo; echo "Demo chosen is $CHOICE"
        ./hack/e2e.sh demos/$CHOICE
        CHOICE=""
    else      
        clear
        cat banner
    fi 
    echo;
done  