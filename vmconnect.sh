#!/bin/zsh
set -eo pipefail

ssh -i ~/.ssh/${SSH_KEY} ubuntu@${AZ_CLUSTER_NAME}redis${1}.westeurope.cloudapp.azure.com $2
