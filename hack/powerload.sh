#!/usr/bin/env bash 
#!/bin/bash
SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source $SCRIPTDIR/config.sh 

for dir in $MANIFEST_DIR/*
do
   echo "kubectl apply -f $dir "
   kubectl apply -f $dir 
done 