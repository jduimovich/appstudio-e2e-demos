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

#
function updateserverinfo() {
    export WHICH_SERVER=$(oc whoami)
    export APP_STUDIO=$(echo "$WHICH_SERVER" | grep  "appstudio-") 
    if [ -n "$APP_STUDIO" ]
    then
        export APP_STUDIO_NS=$(oc project --short)
        export MODE="$APP_STUDIO_NS"
    else
        export MODE="(namespace per project)\n"
        export  APP_STUDIO_NS="error"
    fi
    export  CONTEXT=$(oc config current-context)
}

updateserverinfo   

function prompt_for_multiselect {

    # little helpers for terminal print control and key input
    ESC=$( printf "\033")
    cursor_blink_on()   { printf "$ESC[?25h"; }
    cursor_blink_off()  { printf "$ESC[?25l"; }
    cursor_to()         { printf "$ESC[$1;${2:-1}H"; }
    print_inactive()    { printf "$2   $1 "; }
    print_active()      { printf "$2  $ESC[7m $1 $ESC[27m"; }
    get_cursor_row()    { IFS=';' read -sdR -p $'\E[6n' ROW COL; echo ${ROW#*[}; }
    key_input()         {
      local key
      IFS= read -rsn1 key 2>/dev/null >&2 
 
      if [[ $key = ""      ]]; then echo enter; return ; fi;
      if [[ $key = $'\x20' ]]; then echo space; return ; fi;
      if [[ $key = $'\x1b' ]]; then
        read -rsn2 key
        if [[ $key = [A ]]; then echo up;   return ;  fi;
        if [[ $key = [B ]]; then echo down; return ;  fi;
      fi 
      echo $key
    }
    select_all()    {  
      local arr_name=$1
      eval "local arr=(\"\${${arr_name}[@]}\")"
      for option in "${!options[@]}"; do
        arr[option]=true
      done  
      eval $arr_name='("${arr[@]}")'
    }
    select_none()    {  
      local arr_name=$1
      eval "local arr=(\"\${${arr_name}[@]}\")"
      for option in "${!options[@]}"; do
        arr[option]=false
      done  
      eval $arr_name='("${arr[@]}")'
    }

    toggle_option()    {
      local arr_name=$1
      eval "local arr=(\"\${${arr_name}[@]}\")"
      local option=$2
      if [[ ${arr[option]} == true ]]; then
        arr[option]=false
      else
        arr[option]=true
      fi
      eval $arr_name='("${arr[@]}")'
    }

    local retval=$1
    local lastkey=$4
    local options
    local defaults

    IFS=';' read -r -a options <<< "$2"
    if [[ -z $3 ]]; then
      defaults=()
    else
      IFS=';' read -r -a defaults <<< "$3"
    fi
    local selected=()

    for ((i=0; i<${#options[@]}; i++)); do
      selected+=("${defaults[i]}")
      printf "\n"
    done

    # determine current screen position for overwriting the options
    local lastrow=`get_cursor_row`
    local startrow=$(($lastrow - ${#options[@]}))

    # ensure cursor and input echoing back on upon a ctrl+c during read -s
    trap "cursor_blink_on; stty echo; printf '\n'; exit" 2
    cursor_blink_off

    local active=0
    while true; do
        # print options by overwriting the last lines
        local idx=0
        for option in "${options[@]}"; do
            local prefix="[ ]"
            if [[ ${selected[idx]} == true ]]; then
              prefix="[x]"
            fi

            cursor_to $(($startrow + $idx))
            if [ $idx -eq $active ]; then
                print_active "$option" "$prefix"
            else
                print_inactive "$option" "$prefix"
            fi
            ((idx++))
        done
        cat $TAIL

        # user key control
        keypress=`key_input` 
        case $keypress in
            "a")    select_all selected;;
            "n")    select_none selected;; 
            space)  toggle_option selected $active;;
            enter)  break;;
            up)     ((active--));
                    if [ $active -lt 0 ]; then active=$((${#options[@]} - 1)); fi;;
            down)   ((active++));
                    if [ $active -ge ${#options[@]} ]; then active=0; fi;;
            *)      break;;
        esac
    done

    # cursor position back to normal
    cursor_to $lastrow
    printf "\n"
    cursor_blink_on
   
    eval $retval='"'${selected[@]}'"'
    eval $lastkey='"'$keypress'"'
}

BUNDLE=default   
BANNER=banner
TAIL=tail 
CHOICE=    
PROMPT_DEMOS=""
SELECTED_DEMOS=""
seperator=""
for x in ${DEMOS[@]}
do 
    PROMPT_DEMOS=$PROMPT_DEMOS$seperator$x
    SELECTED_DEMOS=$SELECTED_DEMOS$seperator"false"
    seperator=";"
done   

until [ "${SELECT^}" == "q" ]; do
    clear 
    cat $BANNER 
    printf  "\nBuild: %s Context: %s Namespace: %s\n" "$BUNDLE"  "$CONTEXT" "$MODE"
    printf "Select apps (space to select/deselect, a for all, n for none)\n\n" 
    prompt_for_multiselect result "$PROMPT_DEMOS" "$SELECTED_DEMOS" SELECT   
    # recompute selected next loop  
    SELECTED_DEMOS=${result// /;} 

    if [ "$SELECT" = "a" ]; then 
        echo; echo "Running All" 
        for key in $(seq $COUNTER)
        do   
            ./hack/e2e.sh demos/${DEMOS[$key]} $BUNDLE
        done 
    fi
    if [ "$SELECT" = "r" ]; then 
        let SCOUNTER=1
        for selected in $result
        do  
            if [ "$selected" = "true" ]; then 
                echo "Installing ${DEMOS[$SCOUNTER]} "
                ./hack/e2e.sh demos/${DEMOS[$SCOUNTER]} $BUNDLE  
            fi
            let SCOUNTER++
        done
    fi     
    if [ "$SELECT" = "t" ]; then   
        if [ -n "$APP_STUDIO" ]
        then 
            # one namespace, so build all in that one only
            ./hack/build-all.sh $APP_STUDIO_NS
        else
            let SCOUNTER=1
            for selected in $result
            do  
                if [ "$selected" = "true" ]; then 
                    echo "Trigger Pipeline in ${DEMOS[$SCOUNTER]} "
                    ./hack/build-all.sh ${DEMOS[$SCOUNTER]}
                    ./hack/e2e.sh demos/${DEMOS[$SCOUNTER]} $BUNDLE  
                fi
                let SCOUNTER++
            done 
        fi 
    fi
    if [ "$SELECT" = "s" ]; then  
        echo "--------------------------------"
        echo "STATUS "
        ALL_NS="--all-namespaces"
        if [ -n "$APP_STUDIO" ]
        then
            ALL_NS=""       
        fi  
        KEYS=$(oc get  application.appstudio.redhat.com -o yaml $ALL_NS | yq '.items[].metadata.name' | xargs -n1 echo -n " " )
        echo 
        for app in $KEYS
        do  
            NS=$app
            if [ -n "$APP_STUDIO" ]
            then
                NS=$APP_STUDIO_NS 
            fi   
            printf "\nApplication: $app\n" 
            if [ -d demos/$app/components/ ]; then   
                for c in demos/$app/components/*
                do 
                # for speed, component name is just path
                #NM=$(yq '.metadata.name' $c)
                NM=$(basename $c)
                REPO=$(yq '.spec.source.git.url' $c)
                printf "\tComponent: %s @ %s\n" $NM $REPO
                done
            else
                echo "External app to this demo, will show contents"
            fi 
            if [ -n "$APP_STUDIO" ]
            then
                NS=$APP_STUDIO_NS
            else
                NS=$app
            fi  
            GOPS=$(oc get application $app -n $NS -o yaml | \
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
        done  
    fi  
    if [ "$SELECT" = "q" ]; then 
        echo 
        echo "Exiting..."
        exit
    fi 
    if [ "$SELECT" = "c" ]; then 
        echo 
        echo "Switching to context called appstudio." 
        echo "running oc config use-context appstudio"
        echo "To see a list of available contexts use kubectl config get-contexts"
        oc config  use-context appstudio
        updateserverinfo
        read -n1 -p "press key to continue: "  WAIT
    fi 
    if [ "$SELECT" = "l" ]; then 
        echo 
        echo "Switching to context for local CRC"
        echo "To see a list of available contexts use kubectl config get-contexts"
        echo "running oc config use-context crc-admin"
        oc config  use-context  "crc-admin"
        updateserverinfo
        read -n1 -p "press key to continue: "  WAIT
    fi 
    if [ "$SELECT" = "p" ]; then
        echo
        echo "Show all pipelines"
        ./hack/ls-builds.sh 
        read -n1 -p "Press any key to continue ..."  WAIT
    fi
    if [ "$SELECT" = "h" ]; then 
        echo; echo "Configure all new projects to use the HACBS Repos"
        BUNDLE=hacbs
    fi
    if [ "$SELECT" = "d" ]; then 
        echo; echo "Configure all new projects to use the default bundle"
        BUNDLE=default       
    fi 
done  

