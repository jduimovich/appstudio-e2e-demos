 #!/bin/bash
SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

NS=$1
if [ -z "$NS" ]
then
  source $SCRIPTDIR/select-ns.sh  $C 
fi  
RTS=$(kubectl get routes  -n $NS -o yaml | yq e '.items[].metadata.name | select(. == "el*")')
for rt in $RTS 
do
  C="${rt:2}" 
  $SCRIPTDIR/build-component.sh $C $NS
done
