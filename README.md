# Running code-server locally on Kubernetes using k3s

This article is going to be a short introduction and tutorial on [code-server](https://github.com/cdr/code-server) and how to quickly get it running locally on Kubernetes.



intro.... code server is.... it does.... blah blah balh






## Kubernetes

[k3s](https://k3s.io/) is a lightweight Kubernetes distribution, which packages the k8s control plane and worker nodes into individual binaires called the "k3s Server" and "k3s Agent". We are going to use another tool from Rancher, [k3d](https://github.com/rancher/k3d), which is a wrapper around k3s that allows for quick creation of a k3s environment running in docker containers.

### Docker required

Naturally, completing the steps described in this article will require Docker be installed on your local system. Installing Docker is outside the scope of this document, but there are many sources online covering this information.

### install k3d

k3d can be installed many ways, I am going to use their installer script. Many people are uncomfortable with piping curl output to bash, if so, you can grab the binary from their [releases page](https://github.com/rancher/k3d/releases).

```
curl -s https://raw.githubusercontent.com/rancher/k3d/main/install.sh | bash
```

## Create the Cluster

Next, we will create the Kubernetes cluster on our local machine. You can quickly create a cluster by using the `k3d create` command, which will create the k3s-default cluster, but we need to customize things a bit. k3s comes with the [traefik ingress controller](https://containo.us/traefik/) by default, and in order to access the code-server application we need to expose the ingress controller's port to our host machine.

```:bash
k3d cluster create -p 8081:80@loadbalancer devk8s
```

This commdand creates the k3s cluster, while mapping the host's port 8081 to port 80 on the k3d load balancer container and finally gives the clustser the name `devk8s`. Once the cluster is up and running, you can use the `k3d cluster list` to view the list of clusters currently running on your system.

```
> k3d cluster list
NAME     SERVERS   AGENTS   LOADBALANCER
devk8s   1/1       0/0      true
```

## Access the Cluster

To access the cluster we need to install the kubectl cli tool and generate its config file. To get the latest kubectl binary use the following curl command from the offical documentation. This will download the current binary into your current working directory, mark it executable `chmod +x kubectl` and place it somewhere in your path, I typically use `/usr/local/bin`.

```
curl -LO "https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl && mv kubectl /usr/local/bin
```

Now we need to get a config file for kubectl and we will be ready to go! When working on these local development projects, I like to store the kubectl config file in a directory named `.kube` in my project directory. We will use k3d to generate the config file, store it in the `.kube` directory and then export the `$KUBECONFIG` environment variable to point kubectl to this new config file.

```
k3d kubeconfig get devk8s > .kube/config.yaml
export KUBECONFIG=$(pwd)/.kube/config.yaml


## helm
```
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
chmod +x get_helm.sh && ./get_helm.sh
```

## cert manager

```
# creeate namespace
kubectl create namespace cert-manager
helm repo add jetstack https://charts.jetstack.io
helm repo update

helm install \
  cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --version v1.0.1 \
  --set installCRDs=true

```