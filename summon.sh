#!/bin/zsh
set -euo pipefail

### HEADER ###
MYSTARTTIME=$(date)
echo "Starting deployment at $MYSTARTTIME"

### CREATING THE RG ###
if [ $(az group list | grep ${AZ_CLUSTER_RG} | wc -l) -eq 0 ]; then
    echo "*** Creating resource group ${AZ_CLUSTER_RG}";
    az group create --name ${AZ_CLUSTER_RG} --location ${AZURE_REGION}
fi

### Creating the cluster
echo "Hello Azure! Want my cluster please..."
az aks create -g $AZ_RG -n $AZ_CLUSTER_NAME --location $AZ_REGION --ssh-key-value $SSH_PUB_KEY --tags "owner=jay" --outbound-type loadBalancer --load-balancer-sku standard -s standard_d16s_v4 --node-osdisk-size 200

### Getting kubectl to listen to me...
az aks get-credentials -g $AZ_RG -n $AZ_CLUSTER_NAME -a --overwrite-existing

### Creating the ingress
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

helm install ingress-nginx ingress-nginx/ingress-nginx --create-namespace --namespace $AZ_CLUSTER_INGRESS_NAMESPACE

echo "Waiting for ingress to be ready\n"
while [ true ];
  do
    if [[ $(kubectl get service/ingress-nginx-controller -n ingress -o json | jq ".status.loadBalancer" | grep "\." | wc -l) == *"1"* ]]; then break; fi
    printf "."
    sleep 3s
  done
  printf "\n\n"

### Create some apps for good measures
kubectl apply -f app1.yaml --namespace $AZ_CLUSTER_INGRESS_NAMESPACE
kubectl apply -f app2.yaml --namespace $AZ_CLUSTER_INGRESS_NAMESPACE

### Create the ingress routing
echo "- Waiting - for 30 seconds on our apps and K8s..."
echo "Creating ingress routing for the demo apps"
sleep 30
kubectl apply -f ingress.yaml --namespace $AZ_CLUSTER_INGRESS_NAMESPACE

### Getting custom resources right - installing Redis Enterprise...
echo "Creating Enterprise Redis in the cluster..."
kubectl create namespace $AZ_CLUSTER_REDIS_NAMESPACE
kubectl apply -f bundle.yaml --namespace $AZ_CLUSTER_REDIS_NAMESPACE

### DONE
echo "\n\n"
echo "Start $MYSTARTTIME"
echo "End $(date)"
echo "All done - happy to serve!"
