### scratchpad

# get the endpoint
kubectl get redb/redis-enterprise-database -o jsonpath="{.status.internalEndpoints}"

# get the PW
kubectl get secret redb-redis-enterprise-database -o jsonpath="{.data.password}" | base64 --decode ; echo

# do the port forward --> replace "xxxxx" with port from 2 commands ago
kubectl port-forward service/redis-enterprise-database 16379:xxxxx

# connect to the little wee DB
redis-cli -p 16379
