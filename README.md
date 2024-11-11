# About

Here are some brief instructions on how to install cloudBees Ci on OpenShift CRC local
This has been tested on MacOs 14.7.1 M1

# Links
* https://github.com/cloudbees/support-shinobi-tools/discussions/2075
* https://blogbypuneeth.medium.com/install-redhat-openshift-local-on-mac-m1-c44bf4639692
* https://www.redhat.com/en/blog/codeready-containers
* https://crc.dev/crc/getting_started/getting_started/introducing/
* https://www.redhat.com/en/resources/openshift-skill-paths-datasheet 

# Pre requirements

* A RedHat (free) personal account: register [here](https://www.redhat.com/wapps/ugc/register.html?_flowId=register-flow&_flowExecutionKey=e1s1). 
* A machine with 32Go of memory is very highly recommended.
* At least 40Go of free storage
* Nothing listening on port 443. This is especially a problem if you deploy CBCI in kind (eg with shinobi). Delete the kind cluster(s) you have if necessary (kind delete cluster --name <>, list them with kind get clusters).
helm

# Install CRC

* https://blogbypuneeth.medium.com/install-redhat-openshift-local-on-mac-m1-c44bf4639692
* https://crc.dev/crc/getting_started/getting_started/installing/ 

# Pre configure

## adjust memory and cpu 

```
crc config set cpus 8
#this works, but your will have limited resources, controller resources need to be reduced, see below
crc config set memory 16000 
#to be tested, but if possible use this. might require more than 32 GB on your machine
#crc config set memory 20000 
crc config  get cpus
crc config  get memory
```


# stop and restart to apply the changes 

When cpu and memory has been updated, you need to restart crc

```
crc stop
crc start
```


#  install CB CI 

```
#create new oc project (namespace)
oc new-project cjoc && oc project cjoc
#install CloudBees CI 
./installHelm.sh
```

# create Controller
Because of limited resources, we need to limit the controller cpu and memory to a minimum 
* Create a new Controller on Cjoc
* Open  CJOC -> Controller provisioning page 
* Minimize CPU and Memory
* CPU: 0.5
* Memory: 2048 
* Start the Controller

# Test Pipeline

OC manages its own user id range, so security context with user id 1000 will not work
see [Jenkinsfile.groovy](Jenkinsfile.groovy)
