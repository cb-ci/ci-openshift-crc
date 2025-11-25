# CloudBees CI on OpenShift CRC

This guide provides instructions on how to install CloudBees CI on a local OpenShift CRC cluster.

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

## Installation

1.  **Install CRC**:
    - Follow the official instructions to install CRC for your operating system: [Getting Started with Red Hat OpenShift Local](https://crc.dev/crc/getting_started/getting_started/installing/).
    - An alternative guide can be found [here](https://blogbypuneeth.medium.com/install-redhat-openshift-local-on-mac-m1-c44bf4639692).

2.  **Configure CRC**:
    - Adjust the CPU and memory allocation for the CRC virtual machine. While 16GB of memory will work, you may experience resource constraints. If your machine has more than 32GB of RAM, consider allocating more memory to CRC.

    ```bash
    crc config set cpus 8
    crc config set memory 16000 # 16GB, recommended minimum
    # crc config set memory 20000 # 20GB, if you have enough RAM
    crc config get cpus
    crc config get memory
    ```

3.  **Start CRC**:
    - After configuring CRC, you need to set up the cluster. This will use the `pullsecret.txt` file in the current directory.

    ```bash
    crc setup
    ```

    - Then, start the CRC cluster:

    ```bash
    crc start
    ```

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

4.  **Install CloudBees CI**:
    - Create a new project (namespace) for the CloudBees CI Operations Center (CJOC).

    ```bash
    oc new-project cjoc && oc project cjoc
    ```

    - Run the `installHelm.sh` script to deploy CloudBees CI using Helm.

    ```bash
    ./installHelm.sh
    ```

## Configuration

### Create a Controller

Due to the limited resources of a local CRC environment, you need to create a managed controller with reduced resource allocations.

1.  Open the CloudBees CI Operations Center (CJOC) dashboard.
2.  Navigate to the **Controller Provisioning** page.
3.  Create a new controller with the following settings:
    - **Disk Size**: 5 GB
    - **CPU**: 0.5
    - **Memory**: 2048 MB
4.  Start the controller.

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

## Useful Links

- [CloudBees Support Shinobi Tools Discussion](https://github.com/cloudbees/support-shinobi-tools/discussions/2075)
- [Blog: Install Red Hat OpenShift Local on Mac M1](https://blogbypuneeth.medium.com/install-redhat-openshift-local-on-mac-m1-c44bf4639692)
- [CodeReady Containers Blog](https.www.redhat.com/en/blog/codeready-containers)
- [CRC Getting Started Guide](https://crc.dev/crc/getting_started/getting_started/introducing/)
- [OpenShift Skill Paths](https://www.redhat.com/en/resources/openshift-skill-paths-datasheet)
- [Troubleshooting CloudBees CI on Modern Platforms](https://docs.cloudbees.com/docs/cloudbees-ci-kb/latest/troubleshooting-guides/troubleshooting-cloudbees-core-on-modern-platforms-operations-center-is-not-accessible)
