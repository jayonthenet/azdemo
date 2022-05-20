#!/bin/zsh
set -euo pipefail

### HEADER ###
MYSTARTTIME=$(date)
echo "Starting deployment at ${MYSTARTTIME}"

### CREATING THE RG ###
if [ $(az group list | grep ${AZ_CLUSTER_RG} | wc -l) -eq 0 ]; then
    echo "*** Creating resource group ${AZ_CLUSTER_RG}";
    az group create --name ${AZ_CLUSTER_RG} --location ${AZ_REGION}
fi

### CREATING the SSH keys if not present already
if [ ! -f ~/.ssh/${SSH_KEY} ]; then
    echo "*** Creating SSH key ~/.ssh/${SSH_KEY}"
    ssh-keygen -t rsa -f ~/.ssh/${SSH_KEY} -C ${ADMIN_USERNAME}
fi

### Creating the cluster
if [ $(az aks list | grep ${AZ_CLUSTER_NAME} | wc -l) -eq 0 ]; then
    echo "*** Creating AKS cluster ${AZ_CLUSTER_NAME}";
    az aks create -g ${AZ_RG} -n ${AZ_CLUSTER_NAME} --location ${AZ_REGION} --ssh-key-value ~/.ssh/${SSH_KEY}.pub --tags "owner=jay" --outbound-type loadBalancer --load-balancer-sku standard -s ${AZ_K8S_VMS_SIZE} --node-osdisk-size 200
fi

### Getting kubectl to listen to me...
az aks get-credentials -g ${AZ_RG} -n ${AZ_CLUSTER_NAME} -a --overwrite-existing

### Creating the ingress
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

helm install ingress-nginx ingress-nginx/ingress-nginx --create-namespace --namespace ${AZ_CLUSTER_INGRESS_NAMESPACE}

echo "Waiting for ingress to be ready\n"
while [ true ];
  do
    if [[ $(kubectl get service/ingress-nginx-controller -n ingress -o json | jq ".status.loadBalancer" | grep "\." | wc -l) == *"1"* ]]; then break; fi
    printf "."
    sleep 3
  done
  printf "\n\n"

### Create some apps for good measures
kubectl apply -f app1.yaml --namespace ${AZ_CLUSTER_INGRESS_NAMESPACE}
kubectl apply -f app2.yaml --namespace ${AZ_CLUSTER_INGRESS_NAMESPACE}

### Create the ingress routing
echo "- Waiting - for 30 seconds on our apps and K8s..."
sleep 30
echo "Creating ingress routing for the demo apps"
kubectl apply -f ingress.yaml --namespace ${AZ_CLUSTER_INGRESS_NAMESPACE}

### Getting custom resources right - installing Redis Enterprise Operator - and the rest...
echo "Deploying Enterprise Redis Operator in the cluster..."
kubectl create namespace ${AZ_CLUSTER_REDIS_NAMESPACE}
kubectl apply -f bundle.yaml --namespace ${AZ_CLUSTER_REDIS_NAMESPACE}

echo "Waiting for operator to be ready..."
sleep 30

echo "Deploying Redis Enterprise Cluster"
kubectl apply -f cluster.yaml --namespace ${AZ_CLUSTER_REDIS_NAMESPACE}

echo "Waiting for cluster ready state\n"
while [ true ];
  do
    if [[ $(kubectl get rec/demo-rec -n ${AZ_CLUSTER_REDIS_NAMESPACE} | grep "Running" | wc -l) -eq 1 ]]; then break; fi
    printf "."
    sleep 3
  done
  printf "\n\n"

echo "Onwards... attaching webhook to validate all DBs before they're applied on the cluster"
kubectl label namespace ${AZ_CLUSTER_REDIS_NAMESPACE} namespace-name=${AZ_CLUSTER_REDIS_NAMESPACE}
CERT=`kubectl get secret admission-tls -o jsonpath='{.data.cert}' --namespace ${AZ_CLUSTER_REDIS_NAMESPACE}`
cp webhook.yaml webhook-mod.yaml
gsed -i 's/@@CERT@@/'${CERT}'/g' webhook-mod.yaml
gsed -i 's/@@NAMESPACE_OF_SERVICE_ACCOUNT@@/'${AZ_CLUSTER_REDIS_NAMESPACE}'/g' webhook-mod.yaml
kubectl create -f webhook-mod.yaml --namespace ${AZ_CLUSTER_REDIS_NAMESPACE}

echo "Creating your first database - if this fails, the script got the admission controller wrong - check on secret existence first!"
kubectl apply -f database.yaml --namespace ${AZ_CLUSTER_REDIS_NAMESPACE}

### DONE
echo "\n\n"
echo "Start ${MYSTARTTIME}"
echo "End $(date)"
echo "All done - happy to serve!"
