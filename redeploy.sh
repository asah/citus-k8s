#!/bin/bash

# this is hardcoded for now... have to change the kubernetes config if you want to change...
export WORKERS=7

kubectl delete deployment.apps/citus-master service/citus-master service/citus-workers; kubectl delete sts citus-worker; kubectl delete pvc citus-master-pvc; echo "waiting for termination..."; sleep 30; kubectl get all

# https://stackoverflow.com/questions/47389443/finding-the-name-of-a-new-pod-with-kubectl
kubectl apply -f secrets.yaml; kubectl create -f master.yaml; kubectl create -f workers.yaml; echo "waiting..."; sleep 10; kubectl get all; export CITUS_MASTER=$(kubectl get pod -l app=citus-master -o jsonpath="{.items[0].metadata.name}")

# make sure k8s and citus are running
while [ 1 ]; do w=`kubectl get pods | egrep -c 'citus-worker.+Running'`; if [ $w = $WORKERS ]; then break; fi; echo "$w kubernetes containers running, waiting for $WORKERS... "; sleep 3   ; done
echo "all $WORKERS kubernetes containers running."

for i in `seq 0 $(expr $WORKERS - 1)`; do kubectl exec -it citus-worker-$i -- su postgres -c "psql -c \"drop database citus; \""|egrep -v "NOTICE|DETAIL|HINT|DROP"; done
for i in `seq 0 $(expr $WORKERS - 1)`; do kubectl exec -it citus-worker-$i -- su postgres -c "psql -c \"create database citus; \""|egrep -v "NOTICE|DETAIL|HINT|CREATE"; done
for i in `seq 0 $(expr $WORKERS - 1)`; do kubectl exec -it citus-worker-$i -- su postgres -c "psql citus -c \"create extension citus; \""|egrep -v "CREATE EXTENSION"; done
for i in `seq 0 $(expr $WORKERS - 1)`; do kubectl exec -it citus-worker-$i -- su postgres -c "psql citus -c \"alter extension citus update; \""|egrep -v "ALTER EXTENSION"; done

export CITUS_MASTER=$(kubectl get pod -l app=citus-master -o jsonpath="{.items[0].metadata.name}")
kubectl exec -it $CITUS_MASTER -- su postgres -c "psql -c \"drop database citus;\"" |egrep -v "NOTICE|DETAIL|HINT|DROP" # must be its own command...
kubectl exec -it $CITUS_MASTER -- su postgres -c "psql -c \"create database citus;\"" |egrep -v "NOTICE|DETAIL|HINT|CREATE" # must be its own command...
kubectl exec -it $CITUS_MASTER -- su postgres -c "psql citus -c \"create extension citus\""|egrep -v "CREATE"
for i in `seq 0 $(expr $WORKERS - 1)`; do kubectl exec -it $CITUS_MASTER -- su postgres -c "psql citus -c \"SELECT * from master_add_node('citus-worker-$i.citus-workers', 5432);\""; done

while [ 1 ]; do w=`kubectl exec -it $CITUS_MASTER -- su postgres -c "psql -c \"SELECT * FROM master_get_active_worker_nodes(); \"" | grep -c citus-workers`; if [ $w = $WORKERS ]; then break; fi; echo "$w citus workers registered, waiting for $WORKERS... "; sleep 2; done

echo "all $WORKERS citus workers registered."

# create test data and run tests
kubectl exec -it $CITUS_MASTER -- mkdir /home/postgres
kubectl exec -it $CITUS_MASTER -- chown postgres /home/postgres
kubectl exec -it $CITUS_MASTER -- su - postgres -c "psql citus" < citus-test.sql  # "su -" is important so we can write to local disk


