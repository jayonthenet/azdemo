#!/bin/zsh
set -euo pipefail

### HEADER ###
MYSTARTTIME=$(date)
echo "*** Starting deployment at ${MYSTARTTIME}"

### CLEANUP ###
echo "*** Cleanup"
[ -f cloud-init.txt ] && rm cloud-init.txt

### CREATING THE RG ###
if [ $(az group list | grep ${AZ_CLUSTER_RG} | wc -l) -eq 0 ]; then
    echo "*** Creating resource group ${AZ_CLUSTER_RG}";
    az group create --name ${AZ_CLUSTER_RG} --location ${AZ_REGION}
fi

### CREATING the SSH keys if not present already
if [ ! -f ~/.ssh/${SSH_KEY} ]; then
    echo "*** Creating SSH key ~/.ssh/${SSH_KEY}"
    yes "" | ssh-keygen -t rsa -f ~/.ssh/${SSH_KEY} -C ${ADMIN_USERNAME} -N "" >&- 2>&-
fi

echo "*** Creating YAML for cloud-init"
cp node-config.yml cloud-init.txt
gsed -i 's/@@USER_NAME@@/'${ADMIN_USERNAME}'/g' cloud-init.txt
gsed -i 's|@@REDIS_RELEASE@@|'${REDIS_DOWNLOAD_URL}'|g' cloud-init.txt
gsed -i 's/@@REDIS_FILENAME@@/'${REDIS_FILENAME}'/g' cloud-init.txt

### Creating the cluster
echo "*** Hello Azure! Want my cluster please..."
for i in {1..${AZ_VMS_NODECOUNT}}
do
    echo " ** Creating ${i}..."
    az vm create -n ${AZ_CLUSTER_NAME}${i} -g ${AZ_CLUSTER_RG} -l ${AZ_REGION} --size ${AZ_VMS_SIZE} --admin-username ${ADMIN_USERNAME} --ssh-key-values ~/.ssh/${SSH_KEY}.pub  --vnet-name ${AZ_VMS_VNET} --subnet ${AZ_VMS_VNET}subnet --nsg-rule SSH --private-ip-address 10.0.0.$((i+3)) --public-ip-address-allocation static --public-ip-address-dns-name ${AZ_CLUSTER_NAME}redis${i} --public-ip-sku standard --image UbuntuLTS --no-wait --only-show-errors --custom-data cloud-init.txt
done
echo "*** Give Azure 30 seconds to make VMs available for connection"
for i in {1..30}
do
    printf "."
     sleep 1s
done
for i in {1..${AZ_VMS_NODECOUNT}}
do
    VM_JSON=$(az vm list-ip-addresses -n ${AZ_CLUSTER_NAME}${i} -g ${AZ_CLUSTER_RG})
    PRIVATE_IP=$(jq -r '.[].virtualMachine.network.privateIpAddresses[0]' <<< ${VM_JSON})
    PUBLIC_IP=$(jq -r '.[].virtualMachine.network.publicIpAddresses[0].ipAddress' <<< ${VM_JSON})
    
    if [[ $i -eq 1 ]]
    then
        createorjoin="create"
        nameornodes="name ${CLUSTER_FQDN}"
    else
        createorjoin="join"
        nameornodes="nodes 10.0.0.4"
    fi

    COMMAND="rladmin cluster ${createorjoin} addr ${PRIVATE_IP} external_addr ${PUBLIC_IP} ${nameornodes} username ${ADMIN_EMAIL} password ${ADMIN_PASSWORD}"
    
    echo " ** Contacting VM ${i} at ${PUBLIC_IP}"
    ssh -i ~/.ssh/${SSH_KEY} -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ubuntu@${AZ_CLUSTER_NAME}redis${i}.westeurope.cloudapp.azure.com "bash --login -c 'cloud-init status --wait'"
    echo " ** Executing cluster command"
    echo "  * Current IP: ${PUBLIC_IP}"
    echo "  * Create or join: ${createorjoin}"
    echo "  * Name or nodes: ${nameornodes}"
    ssh -i ~/.ssh/${SSH_KEY} -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ubuntu@${AZ_CLUSTER_NAME}redis${i}.westeurope.cloudapp.azure.com "bash --login -c '${COMMAND}'"

    echo " ** Node is in cluster - security up - opening ports for Redis on NIC/NSG"
    az vm open-port -g ${AZ_CLUSTER_RG} -n ${AZ_CLUSTER_NAME}${i} --priority 800 --port 53,5353,8001,8070,8071,8080,8443,9443,10000-19999 -o none --only-show-errors
done

### DONE
echo "\n\n"
echo "*** Start ${MYSTARTTIME}"
echo "*** End $(date)"
echo "All done - happy to serve!"
