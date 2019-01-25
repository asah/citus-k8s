#!/bin/bash

if [ "x$GCLOUD_PROJECT" = "x" ]; then
  echo "please set GCLOUD_PROJECT variable, e.g. mgh-neurology-poc-01"; exit 1
fi
if [ "x$GCLOUD_COMPUTE_ZONE" = "x" ]; then
  echo "please set GCLOUD_COMPUTE_ZONE variable, e.g. us-east1-c"; exit 1
fi
if [ "x$GCLOUD_CLUSTER" = "x" ]; then
  echo "please set GCLOUD_CLUSTER variable to the k8s cluster, e.g. citus-test-asah-01"; exit 1
fi

if ! [ -x "$(command -v gcloud)" ]; then
  /bin/rm -fr google-cloud-sdk-230.0.0-linux-x86_64.tar.gz google-cloud-sdk
  wget https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-230.0.0-linux-x86_64.tar.gz
  tar zxf google-cloud-sdk-230.0.0-linux-x86_64.tar.gz google-cloud-sdk
  ./google-cloud-sdk/install.sh -q
  source ~/.bashrc
fi

if ! [ -x "$(command -v kubectl)" ]; then
  gcloud components install kubectl -q
fi

gcloud components update -q

# interactive login to your google account...
gcloud auth login
gcloud config set project $GCLOUD_PROJECT
gcloud config set compute/zone $GCLOUD_COMPUTE_ZONE
gcloud container clusters get-credentials $GCLOUD_CLUSTER

exec ./redeploy.sh

