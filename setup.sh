#!/bin/bash

export WORKERS=7
kubectl delete deployment.apps/citus-master service/citus-master service/citus-workers; kubectl delete sts citus-worker; kubectl delete pvc citus-master-pvc; echo "waiting for termination..."; sleep 30; kubectl get all

# https://stackoverflow.com/questions/47389443/finding-the-name-of-a-new-pod-with-kubectl
kubectl apply -f secrets.yaml; kubectl create -f master.yaml; kubectl create -f workers.yaml; echo "waiting..."; sleep 10; kubectl get all; export CITUS_MASTER=$(kubectl get pod -l app=citus-master -o jsonpath="{.items[0].metadata.name}")

# make sure k8s and citus are running
while [ 1 ]; do w=`kubectl get pods | egrep -c 'citus-worker.+Running'`; if [ $w = $WORKERS ]; then break; fi; echo "$w kubernetes containers running, waiting for $WORKERS... "; sleep 2; done
while [ 1 ]; do w=`kubectl exec -it $CITUS_MASTER -- su postgres -c "psql -c \"SELECT * FROM master_get_active_worker_nodes(); \"" | grep -c citus-workers`; if [ $w = $WORKERS ]; then break; fi; echo "$w citus workers registered, waiting for $WORKERS... "; sleep 2; done

kubectl exec -it $CITUS_MASTER -- su postgres -c "psql -c \"create database citus;\"" |egrep -v "NOTICE|DETAIL|HINT" # must be its own command...
kubectl exec -it $CITUS_MASTER -- su postgres -c "psql -c \"SELECT run_command_on_workers('create database citus');\""

# requires createdb citus...
kubectl exec -it $CITUS_MASTER -- su postgres -c "psql citus -c \"create extension citus\""
kubectl exec -it $CITUS_MASTER -- su postgres -c "psql citus -c \"SELECT run_command_on_workers('create extension citus'); \"

# create test data and run tests
kubectl exec -it $CITUS_MASTER -- su - postgres -c "psql citus" < citus.sql  # "su -" is important so we can write to local disk

