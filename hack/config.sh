#!/bin/bash 
# this file is sourced and sets ROOT level directorys for logs and caches

THIS_SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# These are used through the scripts

ROOT_DIR=$(realpath $THIS_SCRIPT_DIR/..)  

# generated manifests are stored here
MANIFEST_DIR=$ROOT_DIR/output/manifests
mkdir -p $MANIFEST_DIR

# cached data to prevent many kubectl commands here 
CACHE_DIR=$ROOT_DIR/output/cache
mkdir -p $CACHE_DIR

# logs for all installs here
LOG_DIR=$ROOT_DIR/output/logs
mkdir -p $LOG_DIR

QUICK_PIPELINES=true 
 