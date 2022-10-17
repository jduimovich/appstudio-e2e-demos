#!/usr/bin/env bash 
for dir in ./hack/logs/*
do
   echo "kubectl apply -f $dir "
   kubectl apply -f $dir 
done 