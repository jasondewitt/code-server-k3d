# Running code-server locally on Kubernetes using k3s

This article is going to be a short introduction and tutorial on [code-server](https://github.com/cdr/code-server) and how to quickly get it running locally on Kubernetes. Code-server is a wonderful tool that allows you to run VS Code in a browser window, backed up by a cloud server. This frees developers from resource constraints on their local laptops and helps to create greater parity with prodcution systems by running development code live cloud servers that more closely match the production envrionments.

While code-server is great for doing 'local' development on a remote machine, this is not a guide for setting up a production build of code-server. I am going to explore how to quickly create a local Kubernetes cluster and deploy code-server, to demonstrate the ease of use if it's web-based VS Code development workflow.

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

```:bash
> k3d cluster list
NAME     SERVERS   AGENTS   LOADBALANCER
devk8s   1/1       0/0      true
```

## Access the Cluster

To access the cluster we need to install the kubectl cli tool and generate its config file. To get the latest kubectl binary use the following curl command from the offical documentation. This will download the current binary into your current working directory, mark it executable `chmod +x kubectl` and place it somewhere in your path, I typically use `/usr/local/bin`.

```:bash
curl -LO "https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl && mv kubectl /usr/local/bin
```

Now we need to get a config file for kubectl and we will be ready to go! When working on these local development projects, I like to store the kubectl config file in a directory named `.kube` in my project directory. We will use k3d to generate the config file, store it in the `.kube` directory and then export the `$KUBECONFIG` environment variable to point kubectl to this new config file.

```:bash
mkdir .kube
k3d kubeconfig get devk8s > .kube/config.yaml
export KUBECONFIG=$(pwd)/.kube/config.yaml
```

## Deploying code-server

Now that the Kubernetes cluster is ready, its time to deploy code-server. In the [repo](repo-link) which accompanies this article, I have included a Docker file that runs code-server, a docker-compose file to start the service locally, outside of Kubernetes and a Kubenetes manifest file which will run the code-server container and set up all required kubernetes services.

### Demonstration Purposes Only

For this quick demo i put together a quick Dockerfile and deployment scenario. While these files provide a good starting point, they are not production ready and should NOT be used on an internet-facing system. I recommend using the [offical container](https://hub.docker.com/r/codercom/code-server), provided by the code-server team, if you are intrested in running this in production.

### Up and Running

To make deploying to this local cluster easier, I push the container to Docker Hub and then allow Kubernetes to pull the container from there and avoid any private registry authentication issues. If you are following along at home, feel free to pull my `jasondewitt/code-server` image from Docker Hub, or use your own by building it locally.

```:bash
docker build -t jasondewitt/code-server:latest .
docker push jasondewitt/code-server:latest
```

With the container ready to go, we can now deploy the application to Kubernetes. The included `code-server.yaml` manifest file can be used to deploy the application to your local cluster. All of the required k8s resources are created in this single file, I will explain each section in the file because you should always know what a manifest file will do before applying it to your cluster.

```:yaml
---
apiVersion: v1
kind: Namespace
metadata:
  name: code-server
```

First off, we create a namespace to hold our code-server deployment. Since this is a demo cluster only, this is not required, but it is nice to keep everything in its own namespace. Next in the file a ConfigMap which stores code-server's configuration file. In this file are a number of important settings that you should pay attention to. First is `bind-address`, in this configuration, this must be set to `0.0.0.0/0` in order to function. By default code-server will listen on the local loopback and will not be accessible to the ingress controller. The other important configuration is the authentication, code-server should always be run with some type of authentication, because the integrated terminal gives anyone with access to the web application full filesystem access in the running container. This configuration looks like this, be sure to replace the password:

```:yaml
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: code-server-config
  namespace: code-server
data:
  config.yaml: |
    bind-addr: 0.0.0.0:8080
    auth: password
    password: set_your_password
    cert: false
    user-data-dir: /home/code/data
    extensions-dir: /home/code/extensions
```

Next comes the Deployment section, which tells Kubernetes how to run the container. Most of the cofiguration is fairly standard for a basic deploy, it sets a name for the deploy, instructs it to run in the `code-server` namespace and sets the number of replicas. In the container spec you will find the container this deployment will run, but also a volume and volumeMount. This is how the running container will access the configMap that was created above. The contents of the configMap are mounted to `/home/code/config.yaml` then the `command:` directive is used in this spec to override the containers CMD and load the config file mounted in the volume.

```:yaml
    spec:
      containers:
        - name: code-server
          image: jasondewitt/code-server:latest
          command: ["/usr/bin/code-server","--config","/home/code/config.yaml"]
          volumeMounts:
          - name: config-volume
            mountPath: /home/code/config.yaml
            subPath: config.yaml
          ports:
          - containerPort: 8080
          imagePullPolicy: Always
      volumes:
        - name: config-volume
          configMap:
            name: code-server-config
```

The kubernetes Service configuration maps ports on the k3s agent nodes to ports belonging to the containers running on them. This application requires a simple service definition to map port 80 on the running agents to port 8080 on the container, which was defined above in the configMap and `EXPOSE`'d in the Dockerfile.

Finally, we set up the ingress controller to allow access to code-server. As I mentioned earlier, k3s installs the traefik ingress controller by default, which is great because Traefik can automatically route HTTP requests to the correct container based on the rules we set up in the ingress configuration. Again, since this is a quick demo simply to demonstrate code-server, this ingress definition sets up code-server to take over the default route `/` on the ingress. To chagne this behavior, edit the path declaration to any directory name you like, for example `path: /code`.

```
---
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: code-server-ingress
  namespace: code-server
  annotations:
    ingress.kubernetes.io/ssl-redirect: "false"
spec:
  rules:
  - http:
      paths:
      - path: /
        backend:
          serviceName: code-server-service
          servicePort: 80
```

## Test it out

Now, all this left is to apply this manifest and run the container. Use kubectl to apply the configuration, `kubectl apply -f code-server.yaml` and deploy this application. Assuming all of your pods are happy (check them with `kubectl get pods -n code-server`) you should be able to access VS Code in your browser by visiting `http://localhost:8081`, remember 8081 was the host port we mapped to port 80 on the k3s load balancer container. You should be greeted by a prompt asking for a password, enter the password you used in the configMap section of the manifest and access the editor.

From this point you are ready to go. You can right click on the code-server window and click "open integrated terminal" to open a command line inside your development container. If you used my Dockerfile you will have access to a basic development environment, the git and ssh utilties are pre-installed so you have everything you need to clone a repository and start coding!
