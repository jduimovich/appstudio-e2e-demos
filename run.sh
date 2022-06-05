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
 
CHOICE=
until [ "${CHOICE^}" != "" ]; do
    echo -n 
    clear
    cat banner
    echo "--------------------------------"
    for key in ${!sorted[@]} 
    do 
        echo "$key : ${DEMOS[$key]}" 
    done 
    read -n1 -p "Choose Demo (q to quit): "  SELECT
    echo $SELECT
    if [ "$SELECT" = "q" ]; then 
        echo "Exiting..."
        exit
    fi  
    SELECT=${SELECT^}
    if [ -n "$SELECT" ]; then
        CHOICE=${DEMOS[$SELECT]}
    fi 
    echo;
done  
echo "Demo chosen is $CHOICE"
./hack/e2e.sh demos/$CHOICE