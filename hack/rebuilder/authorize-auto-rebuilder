
RT=$(kubectl get routes rebuilder -o jsonpath={.spec.host})
echo "Updating server with token" 
while true 
do
    RT=$(kubectl get routes rebuilder -o jsonpath={.spec.host} 2> /dev/null)  
    if [ -z $RT ]; then
        echo "rebuilder route not ready" 
    else   
        curl -s -k https://$RT/authorize?id=$(oc whoami --show-token) >/tmp/rebuilder-ok 
        if grep -q "OK" /tmp/rebuilder-ok; then
            echo "Success: Authorized at $RT"
            exit
        else
            echo "Failed: Waiting for $RT" 
            sleep 1
        fi
    fi
done