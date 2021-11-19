# azdemo
Quick setup of a demo'able system on Azure. 
- V1 includes K8s (AKS that is)
- V2 will get VMs
- V3 will get Tanzu as K8s option as well

V1 is where we currently are :)

# Prerequisites
Assumption here is, that you're running MacOS (using zsh) with Homebrew at the ready ([https://brew.sh/](https://brew.sh/))

You'll need to brew the following onto your system for everything to work.

1. `brew install direnv`
    - needed to fill all env variables in respect to the project you're currently in
    - copy `envrc-template` to `.envrc` and fill in the ***TODO's*** to activate
2. `brew install azure-cli`
    - well - your interface to Azure
    - please remember to `az login` before use
    - also doing an `az configure` for starters might make your life more readable,
     when setting standard output format from ***json*** to ***table***
3. `brew install helm`
    - "package manager" for K8s - will conveniently deploy nginx as ingress
4. `brew install kubernetes-cli`
    - your interface to K8s - `kubectl`
    - probably as good a time as any to `alias` this to `k` ;-)
4. `brew install gh`
    - [https://github.com/](https://github.com/) command line interface
 
# Setting up

```zsh
gh clone jayonthenet/azdemo
cd azdemo
cp envrc-template .envrc
direnv allow
vi .envrc                             ### You get the idea ;)
az login
./summon.sh
```
# Getting a cluster and a database

```zsh
# Getting the cluster
k apply -f cluster.yaml -n redis

#Getting the database
k apply -f database.yaml -n redis
```

# Accessing the database

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

# Cleaning it all up
Attention! This will wipe the AKS cluster, but not the resource group or anything else.

```sh
./nuke.sh
```