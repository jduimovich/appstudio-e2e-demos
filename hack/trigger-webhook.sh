#!/bin/bash
 # trigger-webhook  
SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

URL=http://$1
TAG=$2 
if [ -z "$TAG" ]
then 
  TAG=$(date +"%Y-%m-%d-%H%M%S") 
fi  
echo "$0 $URL $TAG "

FILE=$(mktemp) 
PATCH=".head_commit.id=\"$TAG\""   
echo "jq $PATCH $SCRIPTDIR/payload.json"    
jq "$PATCH" $SCRIPTDIR/payload.json > $FILE   
#
shopt -s extglob 
OS=$(uname -a) 
case "$OS" in 
*microsoft*) PROGRAM="curl.exe" ;;
*) PROGRAM="curl" ;;
esac
$PROGRAM --silent --insecure -d @$FILE -H 'Content-Type: application/json'  $URL

