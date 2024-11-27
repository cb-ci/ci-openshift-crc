#! /bin/bash

helm install ci cloudbees/cloudbees-core -f values.yaml
#helm install ci cloudbees/cloudbees-core -f values.yaml --dry-run --debug

oc get route cjoc  -o jsonpath='{.status.ingress[0].routerCanonicalHostname}' | xargs dig