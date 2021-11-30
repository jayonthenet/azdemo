#!/bin/zsh

### Nuke the RG contents- leave the IPs
echo "Fare the well VMs in ${AZ_RG} !"
for i in {1..${AZ_VMS_NODECOUNT}}
do
    # Will output JSON array and needs some wrapping to execute
    # az resource list -g jaytest --query "[?type!='Microsoft.Network/publicIPAddresses'].id"
    #echo "az vm delete -n ${AZ_CLUSTER_NAME}${i} -g ${AZ_CLUSTER_RG} -y --no-wait -o json"
    #az vm delete -n ${AZ_CLUSTER_NAME}${i}ip -g ${AZ_CLUSTER_RG} -y --no-wait -o json
    az resource list -g ${AZ_RG} --query "[?type!='Microsoft.Network/publicIPAddresses'].id" | jq -r '.[] | values' | xargs -n1 az resource delete --ids
done
echo "\n Issued the orders - Azure is running to complete \n"
