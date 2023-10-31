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

## 4. Deploy to Kyma - Multitenant

Multitenancy is the ability to serve multiple tenants through single clusters of microservice instances, while strictly isolating the tenants' data.
In contrast to single-tenant mode, applications aren't serving end-user request immediately after deployment, but wait for tenants to subscribe.
CAP has built-in support for multitenancy with the @sap/cds-mtxs package.

### Make CAP Application Multitenant

Uninstall the single tenant version be executing the following command:

```bash
helm uninstall bookshop
```

Execute the following command to make the app multitenant:

```bash
cds add mtx --for production
```

`Note`: Make sure you install the newly added dependencies by executing `npm i`.

### Changes to values.yaml

1. Add the `mtx-api` destination in `backendDestinations` key:

    ```diff
    backendDestinations:
        srv-api:
            service: srv
    +   mtx-api:
    +       service: sidecar
    ```

2. Update image link for sidecar.

3. Run the below mentioned command to build and push the images to your docker registry:

    ```bash
    make push-images
    ```

4. Install the helm chart with the following command:

    ```bash
    helm install bookshop ./chart --set-file xsuaa.jsonParameters=xs-security.json
    ```

### Access

1. Open the subaccount and go to `Instances and Subscriptions` tab.
2. Click on `Create`.
3. Search for `bookshop` and select the default plan.
4. Click on `Create`.
5. Once the subscription is successful, click on `Go to Application`.
6. You'll get an error saying, `No webpage was found for the web address: ....` The web address should be of the form: `https://<your-host>.c-4e4de85.stage.kyma.ondemand.com`. Copy the `your-host` value. You'll need it in the next step.
7. Configure your host and release name in the `api-rule.yaml` file available in the `files` folder of your fork.
8. Apply it using the following command `kubectl apply -f files/api-rule.yaml`.
9. Open the web address.
10. Repeat the same steps from 1-9 for other tenants (different subaccount). Make sure to add unique `metadata.name` (release name) in step 7.

---
