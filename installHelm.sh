#! /bin/bash

helm install ci cloudbees/cloudbees-core -f values.yaml
#helm install ci cloudbees/cloudbees-core -f values.yaml --dry-run --debug