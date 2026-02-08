#! /bin/bash

NAMESPACE=cb-ci
oc new-project $NAMESPACE
oc project $NAMESPACE

## https://artifacthub.io/packages/helm/cloudbees/cloudbees-core
#helm repo add cloudbees https://public-charts.artifacts.cloudbees.com/repository/public/
helm repo add cloudbees https://charts.cloudbees.com/public/cloudbees
helm repo update
helm install ci cloudbees/cloudbees-core -f values.yaml
#helm install ci cloudbees/cloudbees-core -f values.yaml --dry-run --debug

oc get route cjoc  -o jsonpath='{.status.ingress[0].routerCanonicalHostname}' | xargs dig