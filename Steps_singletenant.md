# Steps to follow

## 1. Prepare Kyma Namespace

### Prerequisites

- Command Line Tools: [`kubectl`](https://kubernetes.io/de/docs/tasks/tools/install-kubectl/), [`kubectl-oidc_login`](https://github.com/int128/kubelogin#setup), [`pack`](https://buildpacks.io/docs/tools/pack/), [`docker`](https://docs.docker.com/get-docker/), [`helm`](https://helm.sh/docs/intro/install/)
- `@sap/cds-dk` >= 7.0.1

### Prepare your application for deployment

#### Get kubeconfig

1. Open the subaccount and go to the Kyma Environment section.
2. Click on `KubeconfigURL` to download the kubeconfig File.
3. Export the kubeconfig using the command:

    Windows:

    `set KUBECONFIG=<path-to-your-downloaded-file>`.

    macOS:

    `export KUBECONFIG=<path-to-your-downloaded-file>`.

#### Prepare Kubernetes Namespace

Change namespace to your own using: `kubectl config set-context --current --namespace=default`

#### Create container registry secret-

Create a secret `docker-secret` with credentials to access the container registry:

```bash
kubectl create secret docker-registry docker-secret --docker-username=$USERNAME --docker-password=$API_KEY --docker-server=$YOUR_CONTAINER_REGISTRY 
```

This will create a K8s secret, `docker-secret`, in your namespace.

---

## 2. Containerizing a CAP Application

### Overview

A CAP Application (single) usually has three modules:

- Backend (srv)
- DB Deployer
- Frontend (Approuter or HTML5 App Deployer)

### Docker login

Login to docker using the following command:

```bash
docker login -u "$USERNAME" -p "$API_KEY" $YOUR_CONTAINER_REGISTRY
```

### Containerize

1. Create a Makefile in the root of your project.

    ```make
    # Replace `$YOUR_CONTAINER_REGISTRY` with the full-qualified hostname of your container registry
    DOCKER_ACCOUNT=$YOUR_CONTAINER_REGISTRY

    # Builds all modules in the current project by compiling contained CDS sources for production
    build:
        cds build --production

    # Build sidecar image
    build-sidecar:
	    pack build bookshop-sidecar --path gen/mtx/sidecar --buildpack gcr.io/paketo-buildpacks/nodejs --builder paketobuildpacks/builder:base --env BP_NODE_RUN_SCRIPTS=""
	    docker tag bookshop-sidecar:latest $(DOCKER_ACCOUNT)/bookshop-sidecar:latest

    # Build image for CAP service
    build-srv:
        pack build bookshop-srv --path gen/srv --buildpack gcr.io/paketo-buildpacks/nodejs --builder paketobuildpacks/builder:base --env BP_NODE_RUN_SCRIPTS=""
        docker tag bookshop-srv:latest $(DOCKER_ACCOUNT)/bookshop-srv:latest

    # Build Approuter Image
    build-uiimage:
        pack build bookshop-approuter --path app --buildpack gcr.io/paketo-buildpacks/nodejs --builder paketobuildpacks/builder:base --env BP_NODE_RUN_SCRIPTS=""
        docker tag bookshop-approuter:latest $(DOCKER_ACCOUNT)/bookshop-approuter:latest

    # Push container images
    push-images: build build-sidecar build-srv build-uiimage
        docker push $(DOCKER_ACCOUNT)/bookshop-sidecar:latest
        docker push $(DOCKER_ACCOUNT)/bookshop-srv:latest
        docker push $(DOCKER_ACCOUNT)/bookshop-approuter:latest
    ```

2. Run the below mentioned command to build and push the images to your docker registry:

    ```bash
    make push-images
    ```

---

## 3. Deploy to Kyma (Single Tenant)

### Consuming SAP HANA Cloud from the Kyma environment

Follow the process mentioned in the [blog_1](https://blogs.sap.com/2022/12/15/consuming-sap-hana-cloud-from-the-kyma-environment/) and [blog_2](https://blogs.sap.com/2023/08/29/kymas-transition-to-modular-architecture/) to make the database accessible from Kyma environment.

### Add Helm Chart

```bash
cds add helm
```

### Configure Helm Chart

Make the following changes in the _`chart/values.yaml`_ file.

1. Change value of `global.domain` key to your cluster domain. 

    Execute the following command to find out your cluster domain:

    ```bash
    kubectl get gateway -n kyma-system kyma-gateway -o jsonpath='{.spec.servers[0].hosts[0]}'
    ```

    Result should be something like:

    ```bash
    *.<xyz123>.kyma.ondemand.com%
    ```

    Your cluster domain is: `<xyz123>.kyma.ondemand.com`

2. Replace `<your-cluster-domain>` in `xsuaa.parameters.oauth2-configuration.redirect-uris` with your cluster domain.

3. Update image links for approuter, srv and db-deployer.

4. Make the following change to add backend destinations required by Approuter.

    ```diff
    -  backendDestinations: {}
    +  backendDestinations:
    +     srv-api:
    +       service: srv
    ```

5. Add your image registry secret.

    ```diff
    global:
      domain: <xyz123>.kyma.ondemand.com
    -  imagePullSecret: {}
    +  imagePullSecret:
    +    name: docker-secret
    ```

6. Install the helm chart with the following command:

    ```bash
    helm install bookshop ./chart --set-file xsuaa.jsonParameters=xs-security.json
    ```

---
