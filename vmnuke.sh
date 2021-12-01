#!/bin/zsh

### Nuke the RG contents - leave the RG
echo "Fare the well resources in ${AZ_RG} !"
az resource list -g ${AZ_RG} -o json | jq -r '.[] | values' | xargs -n1 az resource delete --ids
echo "\n Issued the orders - Azure is running to complete \n"
