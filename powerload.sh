#!/usr/bin/env bash 
for dir in ./hack/logs/*
do
   echo "oc apply -f $dir "
   oc apply -f $dir 
done 