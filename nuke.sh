#!/bin/zsh

### Nuke the cluster
echo "Fare the well mister $AZ_CLUSTER_NAME in $AZ_RG !"
az aks delete -g $AZ_RG -n $AZ_CLUSTER_NAME --yes
echo "\n DONE \n"
