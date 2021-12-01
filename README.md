# azdemo
Quick setup of a demo'able system on Azure. 
- V1 includes K8s (AKS that is)
- V2 will get VMs
- V3 will get Tanzu as K8s option as well

V2 is where we currently are :)

# Prerequisites
Assumption here is, that you're running MacOS (using zsh) with Homebrew at the ready ([https://brew.sh/](https://brew.sh/))

You'll need to brew the following onto your system for everything to work.

1. direnv
    - `brew install direnv`
    - needed to fill all env variables in respect to the project you're currently in
    - copy `envrc-template` to `.envrc` and fill in the ***TODO's*** to activate
2. Azure CLI
    - `brew install azure-cli`
    - well - your interface to Azure
    - please remember to `az login` before use
    - also doing an `az configure` for starters might make your life more readable,
     when setting standard output format from ***json*** to ***table***
3. Helm
    - `brew install helm`
    - "package manager" for K8s - will conveniently deploy nginx as ingress
4. Kubernetes CLI
    - `brew install kubernetes-cli`
    - your interface to K8s - `kubectl`
    - probably as good a time as any to `alias` this to `k` ;-)
4. GitHub CLI
    - `brew install gh`
    - [https://github.com/](https://github.com/) command line interface
5. GNU sed
    - `brew install sed`
    - [https://www.gnu.org/software/sed/](https://www.gnu.org/software/sed/) sed (stream editor) is a non-interactive command-line text editor
    - This will default to `gsed` after being brewed into MacOS, if you're on Linux or WSL please `alias gsed='sed'`to make the scripts work

 
# Setting up

```sh
gh clone jayonthenet/azdemo
cd azdemo
cp envrc-template .envrc
vi .envrc                             ### You get the idea ;)
direnv allow
az login
```
# Summoning Redis on K8s
## Getting an AKS instance on Azure and deploying the Redis operator
```sh
# Yup - that's it! :)
./summon.sh
```
## Getting a cluster and a database

```sh
# Getting the cluster
k apply -f cluster.yaml -n redis

#Getting the database
k apply -f database.yaml -n redis
```

## Accessing the database

```sh
# get the endpoint
kubectl get redb/redis-enterprise-database -o jsonpath="{.status.internalEndpoints}"

# get the PW
kubectl get secret redb-redis-enterprise-database -o jsonpath="{.data.password}" | base64 --decode ; echo

# do the port forward --> replace "xxxxx" with port from 2 commands ago
kubectl port-forward service/redis-enterprise-database 16379:xxxxx

# connect to the little wee DB
redis-cli -p 16379
```

## Cleaning it all up
Attention! This will wipe the AKS cluster, but not the resource group or anything else.

```sh
./nuke.sh
```

# Summoning Redis on VMs

## Getting the VMs in Azure ready, installing Redis and joining them into a cluster
```sh
# Yup - that's it! :)
./vmsummon.sh
```
If you don't have an SSH key yet, you will need to execute the script twice, as it will break after issueing the SSH key.

## Accessing the HTTP interface of your Redis cluster
- Open the browser of your choice
- Check on your `.envrc` for the variable contents to create the real link - pattern/example : [https://((AZ_CLUSTER_NAME))redis1.((AZ_REGION)).cloudapp.azure.com:8443](https://((AZ_CLUSTER_NAME))redis1.((AZ_REGION)).cloudapp.azure.com:8443)
- If your DNS / FQDN setup is working, of course you can also access the cluster on port 8443 via the configured FQDN

## Accessing the VMs of your cluster
```sh
# Replace the number '1' as first parameter to this script to target the corresponding cluster node - e.g. '3' would target cluster node 3
./vmconnect.sh 1
```

## Cleaning it all up

```sh
# Nuke the contents, but keep the resource group with it's deployment history.
./vmnuke.sh

# Nuke the resource group - quicker but wipes the history
az group delete -y -n ${AZ_RG}
```
