#! /bin/bash

crc config set cpus 8
#this works, but your will have limited resources, controller resources need to be reduced, see below
crc config set memory 16000
#to be tested, but if possible use this. might require more than 32 GB on your machine
#crc config set memory 20000
crc config  get cpus
crc config  get memory
crc start

eval $(crc oc-env)
#oc login -u developer https://api.crc.testing:6443
oc login -u kubeadmin https://api.crc.testing:6443