#!/bin/bash
SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source $SCRIPTDIR/config.sh 

CMD=$1
APP_DIR=$2
INSTALL_LOG=$3
# fix later to do in parallel
$SCRIPTDIR/$CMD "$APP_DIR" | tee "$INSTALL_LOG"   

