WHICH_SERVER=$(oc whoami)
APP_STUDIO=$(echo "$WHICH_SERVER" | grep  "appstudio-")
echo "whoami: $WHICH_SERVER" 
if [ -n "$APP_STUDIO" ]
then
        echo Running in App Studio
        NS=$(oc project --short)
else   
        NS=$APPNAME   
fi