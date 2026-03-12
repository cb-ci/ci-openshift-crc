# CloudBees CI on OpenShift CRC

This guide provides instructions on how to install CloudBees CI on a local OpenShift CRC cluster.
See also <https://docs.cloudbees.com/docs/cloudbees-ci/latest/openshift-install-guide/>

This setup has been tested on macOS 14.7.1 (M1).

## Table of Contents

- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Configuration](#configuration)
- [Usage](#usage)
- [Troubleshooting](#troubleshooting)
- [Useful Links](#useful-links)

## Prerequisites

Before you begin, ensure you have the following:

- **Red Hat Account**: A free personal account is required. You can register [here](https://www.redhat.com/wapps/ugc/register.html).
- **Hardware**:
  - A machine with at least 32GB of RAM is highly recommended.
  - At least 40GB of free storage.
- **Software**:
  - **CRC**: The CodeReady Containers tool.
  - **Helm**: The Kubernetes package manager.
  - **oc**: The OpenShift command-line client.
- **Network**:
  - Nothing listening on port 443. This can be an issue if you are also running Docker Desktop with a local Kubernetes cluster.
- **Pull Secret**:
  - A pull secret from your Red Hat account is required to pull the necessary container images. Download it from [here](https://console.redhat.com/openshift/install/crc/user-provisioned) and save it as `pullsecret.txt` in this directory.

## Service Account Permissions

On OpenShift, you need to give your “installer” ServiceAccount rights to create both namespace-scoped and cluster-scoped objects.  
In practice, that means you must bind it to a ClusterRole that can:

* Create, update, patch, delete, get, list & watch all of the namespaced resources the chart uses:
  * Namespaces, ServiceAccounts, Roles, RoleBindings
  * Deployments, StatefulSets, Services, ConfigMaps, Secrets
  * NetworkPolicies, PodDisruptionBudgets, Ingresses (networking.k8s.io/v1)
  * Routes (route.openshift.io/v1) and (if you’ve enabled Gateway API) HTTPRoutes
* Create, update, patch, delete, get, list & watch the cluster-scoped resources:
  * ClusterRoles, ClusterRoleBindings
  * CustomResourceDefinitions (apiextensions.k8s.io/v1) (only if you’ve enabled the CasC‐Bundle CRD)
  * StorageClasses

The easiest thing is usually to just give it the built-in cluster-admin role:

```bash
oc adm policy add-cluster-role-to-user cluster-admin \
    -z cbj-dev-001-sa -n cbj-dev-001
```

However, in some cases, full permission can not be assigned.
Therefore, this minimal ClusterRole can be used instead of full cluster-admin.  
It covers all of the API groups & resources the CloudBees Helm chart will attempt to create by default:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
    name: helm-chart-installer
rules:
# namespaced core
- apiGroups: [""]
    resources:
    - namespaces
    - serviceaccounts
    - configmaps
    - secrets
    - services
    - endpoints
    verbs: ["*"]
# namespaced apps
- apiGroups: ["apps"]
    resources: ["deployments","statefulsets"]
    verbs: ["*"]
# namespaced networking
- apiGroups: ["networking.k8s.io"]
    resources: ["networkpolicies","ingresses"]
    verbs: ["*"]
# OpenShift Routes
- apiGroups: ["route.openshift.io"]
    resources: ["routes","routes/custom-host"]
    verbs: ["*"]
# Gateway API (if you enable it)
- apiGroups: ["gateway.networking.k8s.io"]
    resources: ["httproutes"]
    verbs: ["*"]
# PodDisruptionBudget
- apiGroups: ["policy"]
    resources: ["poddisruptionbudgets"]
    verbs: ["*"]
# RBAC
- apiGroups: ["rbac.authorization.k8s.io"]
    resources: ["roles","rolebindings","clusterroles","clusterrolebindings"]
    verbs: ["*"]
# CRDs (only if you enable the Casc-Bundle-Service)
- apiGroups: ["apiextensions.k8s.io"]
    resources: ["customresourcedefinitions"]
    verbs: ["*"]
# StorageClass (only on GKE–if you turn on the GKE storageClass template)
- apiGroups: ["storage.k8s.io"]
    resources: ["storageclasses"]
    verbs: ["*"]
```

Then bind it to your installer SA:

```bash
oc create clusterrolebinding install-charts-binding \
    --clusterrole=helm-chart-installer \
    --serviceaccount=<your-namespace>:<your-serviceaccount>
```

After that, the service account will be able to helm install (or oc apply -f templates/...) without “forbidden” errors.
Note: The ClusterRole permissions can be made more restrictive


## Installation

1. **Install CRC**:
    - Follow the official instructions to install CRC for your operating system: [Getting Started with Red Hat OpenShift Local](https://crc.dev/crc/getting_started/getting_started/installing/).
    - An alternative guide can be found [here](https://blogbypuneeth.medium.com/install-redhat-openshift-local-on-mac-m1-c44bf4639692).
    - I used asdf:

        ```
         asdf plugin add oc https://github.com/asdf-community/asdf-oc.git
         asdf install oc latest       
         asdf local oc latest
        ```

2. **Configure CRC**:
    - Adjust the CPU and memory allocation for the CRC virtual machine. While 16GB of memory will work, you may experience resource constraints. If your machine has more than 32GB of RAM, consider allocating more memory to CRC.

    ```bash
    crc config set cpus 8
    crc config set memory 16000 # 16GB, recommended minimum
    # crc config set memory 20000 # 20GB, if you have enough RAM
    crc config get cpus
    crc config get memory
    ```

3. **Start CRC**:
    - After configuring CRC, you need to set up the cluster. This will use the `pullsecret.txt` file in the current directory.

    ```bash
    crc setup
    ```

    - Then, start the CRC cluster:

    ```bash
    crc start
    ```

    - See also [crc-start.sh](crc-start.sh)
    - Once the cluster is running, you will see output with credentials for `kubeadmin` and `developer` users, and the URL for the OpenShift web console.

    ```
    The server is accessible via web console at:
    https://console-openshift-console.apps-crc.testing

    Log in as administrator:
    Username: kubeadmin
    Password: <password>

    Log in as user:
    Username: developer
    Password: developer

    Use the 'oc' command line interface:
    $ eval $(crc oc-env)
    $ oc login -u developer https://api.crc.testing:6443
    ```

4. **Install CloudBees CI**:
    - Create a new project (namespace) for the CloudBees CI Operations Center (CJOC).

    ```bash
    PROJECT=cb-ci
    oc new-project $PROJECT  && oc project $PROJECT
    ```

    - Run the `installHelm.sh` script to deploy CloudBees CI using Helm.

    ```bash
    ./installHelm.sh
    ```

## Configuration

### Create a Controller

Due to the limited resources of a local CRC environment, you need to create a managed controller with reduced resource allocations.

1. Open the CloudBees CI Operations Center (CJOC) dashboard.
2. Navigate to the **Controller Provisioning** page.
3. Create a new controller with the following settings:
    - **Disk Size**: 5 GB
    - **CPU**: 0.5
    - **Memory**: 2048 MB
4. Start the controller.

## Usage

### Test Pipeline

The example `Jenkinsfile.groovy` in this repository is configured to work with the security context constraints of OpenShift, which manages its own user ID range.

## Troubleshooting

### Pull Secret Issues

If you encounter issues with pulling container images, it may be related to your pull secret.

- [crc issue #4218](https://github.com/crc-org/crc/issues/4218)
- [OKD discussion #716](https://github.com/okd-project/okd/discussions/716)

### Test CJOC from Controller Pod

You can test the connection from a controller pod back to the CJOC.

```bash
curl -Il http://cjoc.cb-ci.svc.cluster.local/whoAmI/api/json?tree=authenticated
```

### Get OC Connection Logs from Controller

```bash
oc exec -ti <controller-pod-name> -- cat /var/jenkins_home/logs/operations-center-connector.log
```

### Test from Controller Script Console

You can also run a test from the script console of a managed controller.

```groovy
def url = new URL("http://cjoc.cb-ci.svc.cluster.local/whoAmI/api/json?tree=authenticated");
def connection = url.openConnection();
println("Response Headers");
println("================");
for (def e in connection.getHeaderFields()) {
  println("${e.key}: ${e.value}");
}
println("\nResponse status: HTTP/${connection.responseCode}\n");
```

### Controller Connection stuck with anyuid

OpenShift security settings prevent the pod from being created when the fsgroup is 1000. The anyuid permission has to be added to the controller service account.
See
- [OpenShift Managing Security Constraints](https://medium.com/@muhammadadel612/managing-security-context-constraints-scc-b48b3c566fa5)
- [OpenShift Security Constraints Explained](https://andreaskaris.github.io/blog/openshift/scc/)
- [OpenShift SCC ](https://examples.openshift.pub/deploy/scc-anyuid/)

One option is to grant this to each service account (controller) separately, which can become difficult:

```
oc adm policy add-scc-to-user anyuid -z <controller-sa> -n YOURNAMMESPACE
```

Another option is to grant these permissions to all the service accounts in the namespace:

```
oc adm policy add-scc-to-group anyuid system:serviceaccounts: YOURNAMESPACE
```

Issue seen when not adding anyuid to the controller service account:

```bash
Warning:   FailedCreate            statefulset/controller                             create Pod controller-0 in StatefulSet controller failed error: pods "controller-0" is forbidden: unable to validate against any security context constraint: [provider "anyuid": Forbidden: not usable by user or serviceaccount, provider restricted-v2: .spec.securityContext.fsGroup: Invalid value: []int64{1000}: 1000 is not an allowed group, provider "restricted": Forbidden: not usable by user or serviceaccount, provider "nonroot-v2": Forbidden: not usable by user or serviceaccount, provider "nonroot": Forbidden: not usable by user or serviceaccount, provider "hostmount-anyuid": Forbidden: not usable by user or serviceaccount, provider "hostmount-anyuid-v2": Forbidden: not usable by user or serviceaccount, provider "machine-api-termination-handler": Forbidden: not usable by user or serviceaccount, provider "hostnetwork-v2": Forbidden: not usable by user or serviceaccount, provider "hostnetwork": Forbidden: not usable by user or serviceaccount, provider "hostaccess": Forbidden: not usable by user or serviceaccount, provider "hostpath-provisioner": Forbidden: not usable by user or serviceaccount, provider "privileged": Forbidden: not usable by user or serviceaccount]
```

## Useful Links

- [Blog: Install Red Hat OpenShift Local on Mac M1](https://blogbypuneeth.medium.com/install-redhat-openshift-local-on-mac-m1-c44bf4639692)
- [CodeReady Containers Blog](https://www.redhat.com/en/blog/codeready-containers)
- [CRC Getting Started Guide](https://crc.dev/crc/getting_started/getting_started/introducing/)
- [OpenShift Skill Paths](https://www.redhat.com/en/resources/openshift-skill-paths-datasheet)
- [OpenShift Managing Security Constraints](https://medium.com/@muhammadadel612/managing-security-context-constraints-scc-b48b3c566fa5)
- [OpenShift Security Constraints Explained](https://andreaskaris.github.io/blog/openshift/scc/) and https://examples.openshift.pub/deploy/scc-anyuid/
- [Troubleshooting CloudBees CI on Modern Platforms](https://docs.cloudbees.com/docs/cloudbees-ci-kb/latest/troubleshooting-guides/troubleshooting-cloudbees-core-on-modern-platforms-operations-center-is-not-accessible)
