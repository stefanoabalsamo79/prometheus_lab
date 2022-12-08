# Prometheus lab

---
***Prerequisites:***
1. [`docker`](https://www.docker.com/)
2. [`kubectl`](https://kubernetes.io/docs/tasks/tools/)
3. [`helm`](https://helm.sh/)
4. [`kind`](https://kind.sigs.k8s.io/)
5. [`yq`](https://github.com/mikefarah/yq)
6. [`jq`](https://stedolan.github.io/jq/download/)

---

### Repository structure

```text
├── Makefile
├── README.md
├── deploy-charts
│   ├── Chart.yaml
│   ├── charts
│   │   ├── deployment
│   │   │   ├── Chart.yaml
│   │   │   ├── templates
│   │   │   │   ├── _helpers.tpl
│   │   │   │   ├── deployment.yaml
│   │   │   │   ├── ingress.yaml
│   │   │   │   └── service.yaml
│   │   │   └── values.yaml
│   │   └── strategy
│   │       ├── Chart.yaml
│   │       ├── templates
│   │       │   ├── _helpers.tpl
│   │       │   ├── rollout.yaml
│   │       │   └── service.yaml
│   │       └── values.yaml
│   ├── templates
│   │   └── _helpers.tpl
│   └── values.yaml
├── images_and_diagrams
├── infra
│   ├── cluster.yaml
│   ├── grafana
│   │   └── grafana.yaml
│   ├── ingress_controller.yaml
│   └── prometheus
│       ├── prom_rbac.yaml
│       ├── prom_svc.yaml
│       ├── prometheus.yaml
│       ├── prometheus_ingress.yaml
│       ├── prometheus_service_app_monitor.yaml
│       └── prometheus_service_self_monitor.yaml
└── src
    ├── Dockerfile
    ├── index.js
    └── package.json
```
* `images_and_diagrams`: folder where some images/gifs are found, readme stuffs in essence
* `deploy-charts/charts/deployment`: helm subchart to publish the nodejs app comprehensive of ingress
* `deploy-charts/charts/strategy`: subchart in order to install the Rollout via which we will manage the deployment in terms of strategy deployment
* `infra/cluster.yaml`: cluster to be created
* `infra/ingress_controller.yaml`: ingress controller manifest to be installed
* `infra/grafana/grafana.yaml`: grafana installation manifest
* `infra/prometheus`: folder containing prometheus installation manifests along with couple of `ServiceMonitor`
* `src`: nodejs application comprehensive of Dockerfile for containerization
* `Makefile`: make file to automatize as much as possible what we do in this lab

### Installing the whole stack
```bash
make all
```
***output:***
```bash
/Library/Developer/CommandLineTools/usr/bin/make print_mk_var \
	cluster_start \
	create_cluster \
	set_context_cluster \
	cluster_info \
	ingress_controller_install \
	wait_for_ingress_controller \
	build_tag_push_image \
	deployment_install \
	prometheus-install-all \
	grafana-install
YQ: [/usr/local/bin/yq]
KUBECTL: [/usr/local/bin/kubectl]
DOCKER: [/usr/local/bin/docker]
PARENT_CHART_VALUES_FILE: [deploy-charts/values.yaml]
DEPLOYMENT_RELEASE_NAME: [test-app-release]
DEFAULT_CLUSTER_NAME: [kind]
CLUSTER_NAME: [test-cluster]
APP_NAME: [test-app]
APP_TAG: [1.0.7]
DEPLOY_NAMESPACE: [default]
IMAGE_NAME_TAG: [test-app:1.0.7]
FULLY_QUALIFIED_IMAGE_URL: [test-app:1.0.7]
/usr/local/bin/kind create cluster
Creating cluster "kind" ...
 ✓ Ensuring node image (kindest/node:v1.25.3) 🖼
 ✓ Preparing nodes 📦
 ✓ Writing configuration 📜
 ✓ Starting control-plane 🕹️
 ✓ Installing CNI 🔌
 ✓ Installing StorageClass 💾
Set kubectl context to "kind-kind"
You can now use your cluster with:

kubectl cluster-info --context kind-kind

Thanks for using kind! 😊
/usr/local/bin/kind create \
	cluster --config=infra/cluster.yaml \
	--name test-cluster
Creating cluster "test-cluster" ...
 ✓ Ensuring node image (kindest/node:v1.25.3) 🖼
 ✓ Preparing nodes 📦
 ✓ Writing configuration 📜
 ✓ Starting control-plane 🕹️
 ✓ Installing CNI 🔌
 ✓ Installing StorageClass 💾
Set kubectl context to "kind-test-cluster"
You can now use your cluster with:

kubectl cluster-info --context kind-test-cluster

Have a nice day! 👋
/usr/local/bin/kubectl config set-context test-cluster
Context "test-cluster" modified.
/usr/local/bin/kubectl cluster-info --context kind-test-cluster
Kubernetes control plane is running at https://127.0.0.1:54661
CoreDNS is running at https://127.0.0.1:54661/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy

To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.
/usr/local/bin/kubectl apply -f infra/ingress_controller.yaml
namespace/ingress-nginx created
serviceaccount/ingress-nginx created
serviceaccount/ingress-nginx-admission created
role.rbac.authorization.k8s.io/ingress-nginx created
role.rbac.authorization.k8s.io/ingress-nginx-admission created
clusterrole.rbac.authorization.k8s.io/ingress-nginx created
clusterrole.rbac.authorization.k8s.io/ingress-nginx-admission created
rolebinding.rbac.authorization.k8s.io/ingress-nginx created
rolebinding.rbac.authorization.k8s.io/ingress-nginx-admission created
clusterrolebinding.rbac.authorization.k8s.io/ingress-nginx created
clusterrolebinding.rbac.authorization.k8s.io/ingress-nginx-admission created
configmap/ingress-nginx-controller created
service/ingress-nginx-controller created
service/ingress-nginx-controller-admission created
deployment.apps/ingress-nginx-controller created
job.batch/ingress-nginx-admission-create created
job.batch/ingress-nginx-admission-patch created
ingressclass.networking.k8s.io/nginx created
validatingwebhookconfiguration.admissionregistration.k8s.io/ingress-nginx-admission created
/Library/Developer/CommandLineTools/usr/bin/make wait_for_ingress_controller
/usr/local/bin/kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s
pod/ingress-nginx-controller-5b9f994b4c-9n88c condition met
/usr/local/bin/kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s
pod/ingress-nginx-controller-5b9f994b4c-9n88c condition met
/Library/Developer/CommandLineTools/usr/bin/make build tag load_image
/usr/local/bin/docker build \
	--pull --no-cache \
	-t test-app:1.0.7 \
	-f ./src/Dockerfile \
	./src
[+] Building 9.9s (9/9) FINISHED
 => [internal] load build definition from Dockerfile                                                                                                                                                         0.0s
 => => transferring dockerfile: 36B                                                                                                                                                                          0.0s
 => [internal] load .dockerignore                                                                                                                                                                            0.0s
 => => transferring context: 2B                                                                                                                                                                              0.0s
 => [internal] load metadata for docker.io/library/node:16                                                                                                                                                   1.7s
 => [internal] load build context                                                                                                                                                                            0.0s
 => => transferring context: 62B                                                                                                                                                                             0.0s
 => [1/4] FROM docker.io/library/node:16@sha256:7f404d09ceb780c51f4fac7592c46b8f21211474aacce25389eb0df06aaa7472                                                                                             0.0s
 => => resolve docker.io/library/node:16@sha256:7f404d09ceb780c51f4fac7592c46b8f21211474aacce25389eb0df06aaa7472                                                                                             0.0s
 => CACHED [2/4] WORKDIR /home/app                                                                                                                                                                           0.0s
 => [3/4] COPY index.js package.json ./                                                                                                                                                                      0.6s
 => [4/4] RUN npm install                                                                                                                                                                                    7.3s
 => exporting to image                                                                                                                                                                                       0.2s
 => => exporting layers                                                                                                                                                                                      0.2s
 => => writing image sha256:5964311c407ff07fa96ffefe549e58a83c82ec4fffbd1d5b60c8a134b19e871e                                                                                                                 0.0s
 => => naming to docker.io/library/test-app:1.0.7                                                                                                                                                            0.0s

Use 'docker scan' to run Snyk tests against images to find vulnerabilities and learn how to fix them
/usr/local/bin/docker tag \
	test-app:1.0.7 \
	test-app:1.0.7
/usr/local/bin/kind load docker-image --name test-cluster test-app:1.0.7
Image: "" with ID "sha256:5964311c407ff07fa96ffefe549e58a83c82ec4fffbd1d5b60c8a134b19e871e" not yet present on node "test-cluster-control-plane", loading...
/usr/local/bin/helm upgrade --install \
	--debug \
	-n default \
	-f deploy-charts/values.yaml \
	--set 'deployment.enabled=true' \
	--set 'strategy.enabled=false' \
	test-app-release ./deploy-charts
history.go:56: [debug] getting history for release test-app-release
Release "test-app-release" does not exist. Installing it now.
install.go:178: [debug] Original chart version: ""
install.go:195: [debug] CHART PATH: /Users/stefanoabalsamo/MyProjects/prometheus-fun/deploy-charts

client.go:128: [debug] creating 3 resource(s)
NAME: test-app-release
LAST DEPLOYED: Thu Dec  8 10:05:24 2022
NAMESPACE: default
STATUS: deployed
REVISION: 1
TEST SUITE: None
USER-SUPPLIED VALUES:
clusterName: test-cluster
defaultClusterName: kind
deployemntReleaseName: test-app-release
deployment:
  app:
    name: test-app
    tag: 1.0.7
  enabled: true
grafanaNamespace: default
prometheusNamespace: default
strategy:
  enabled: false

COMPUTED VALUES:
clusterName: test-cluster
defaultClusterName: kind
deployemntReleaseName: test-app-release
deployment:
  app:
    name: test-app
    tag: 1.0.7
  deployment:
    namespace: default
    replicas: 3
  enabled: true
  global: {}
grafanaNamespace: default
prometheusNamespace: default
strategy:
  enabled: false

HOOKS:
MANIFEST:
---
# Source: deploy-charts/charts/deployment/templates/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: test-app-service
  labels:
    app: test-app
spec:
  type: ClusterIP
  selector:
    app: test-app
  ports:
  - port: 8080
    protocol: TCP
    targetPort: 8080
    name: http
  sessionAffinity: None
---
# Source: deploy-charts/charts/deployment/templates/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-app-deployment
  annotations:
    version: 1.0.0
spec:
  progressDeadlineSeconds: 600
  revisionHistoryLimit: 10
  selector:
    matchLabels:
      app: test-app
  replicas: 3
  strategy:
    rollingUpdate:
      maxSurge: 25%
      maxUnavailable: 25%
    type: RollingUpdate
  template:
    metadata:
      labels:
        app: test-app
    spec:
      securityContext: {}
      terminationGracePeriodSeconds: 30
      containers:
        - name: test-app
          image: test-app:1.0.7
          imagePullPolicy: IfNotPresent
          env:
          - name: TEST_VAR
            value: 1.0.4
          ports:
          - containerPort: 8080
            protocol: TCP
            name: http
          resources:
            limits:
              cpu: 300m
              memory: 1G
            requests:
              cpu: 200m
              memory: 500M
---
# Source: deploy-charts/charts/deployment/templates/ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: test-app-ingress
spec:
  rules:
  - http:
      paths:
      - pathType: Prefix
        path: "/app"
        backend:
          service:
            name: test-app-service
            port:
              number: 8080
      - pathType: Prefix
        path: "/app-metrics"
        backend:
          service:
            name: test-app-service
            port:
              number: 8080

/Library/Developer/CommandLineTools/usr/bin/make prometheus-operator-install \
	prometheus-rbac-install \
	prometheus-install \
	wait_for_prom_operator_deploy \
	wait_for_prom_statefulset \
	wait_for_prom_pods \
	prometheus-svc-install \
	prometheus-ui-ingress-install \
	prometheus-self-monitor-install \
	prometheus-app-monitor-install
/usr/local/bin/kubectl create -n default -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/master/bundle.yaml
customresourcedefinition.apiextensions.k8s.io/alertmanagerconfigs.monitoring.coreos.com created
customresourcedefinition.apiextensions.k8s.io/alertmanagers.monitoring.coreos.com created
customresourcedefinition.apiextensions.k8s.io/podmonitors.monitoring.coreos.com created
customresourcedefinition.apiextensions.k8s.io/probes.monitoring.coreos.com created
customresourcedefinition.apiextensions.k8s.io/prometheuses.monitoring.coreos.com created
customresourcedefinition.apiextensions.k8s.io/prometheusrules.monitoring.coreos.com created
customresourcedefinition.apiextensions.k8s.io/servicemonitors.monitoring.coreos.com created
customresourcedefinition.apiextensions.k8s.io/thanosrulers.monitoring.coreos.com created
clusterrolebinding.rbac.authorization.k8s.io/prometheus-operator created
clusterrole.rbac.authorization.k8s.io/prometheus-operator created
deployment.apps/prometheus-operator created
serviceaccount/prometheus-operator created
service/prometheus-operator created
/usr/local/bin/kubectl apply -n default -f infra/prometheus/prom_rbac.yaml
serviceaccount/prometheus created
clusterrole.rbac.authorization.k8s.io/prometheus created
clusterrolebinding.rbac.authorization.k8s.io/prometheus created
/usr/local/bin/kubectl apply -n default -f infra/prometheus/prometheus.yaml
prometheus.monitoring.coreos.com/prometheus created
/usr/local/bin/kubectl wait \
	deployment -n default \
	prometheus-operator \
	--for condition=Available=True \
	--timeout=300s
deployment.apps/prometheus-operator condition met
/usr/local/bin/kubectl rollout \
	-n default \
	status --watch --timeout=300s \
	statefulset/prometheus-prometheus
Waiting for 2 pods to be ready...
Waiting for 1 pods to be ready...
statefulset rolling update complete 2 pods at revision prometheus-prometheus-6fc466f657...
/usr/local/bin/kubectl wait \
	-n default \
	--for condition=ready \
	--timeout=300s \
	pod -l prometheus=prometheus
pod/prometheus-prometheus-0 condition met
pod/prometheus-prometheus-1 condition met
/usr/local/bin/kubectl apply -n default -f infra/prometheus/prom_svc.yaml
service/prometheus created
/usr/local/bin/kubectl patch svc prometheus \
	-n default \
	--type=json -p='[{"op": "add", "path": "/spec/selector/prometheus", "value": "prometheus"}]'
service/prometheus patched
/usr/local/bin/kubectl patch svc prometheus \
	-n default \
	--type=json -p='[{"op": "remove", "path": "/spec/selector/app"}]'
service/prometheus patched
/usr/local/bin/kubectl apply -n default -f infra/prometheus/prometheus_ingress.yaml
ingress.networking.k8s.io/prometheus-operated-ingress created
/usr/local/bin/kubectl apply -n default -f infra/prometheus/prometheus_service_self_monitor.yaml
servicemonitor.monitoring.coreos.com/prometheus-self created
/usr/local/bin/kubectl apply -n default -f infra/prometheus/prometheus_service_app_monitor.yaml
servicemonitor.monitoring.coreos.com/test-app-svc-monitor created
/usr/local/bin/kubectl apply -n default -f infra/grafana/grafana.yaml
persistentvolumeclaim/grafana-pvc created
deployment.apps/grafana created
```

### Once the installation is over let's start generating metrics for the test-app via invoking itself
```bash
watch -n 0.1 curl http://localhost/app
```

### Let's portforward grafana so we can access to its UI
![`image_001`](./images_and_diagrams/image_001.png)

---
***Notes:*** \
Default credentials: **admin** / **admin** \
You will be asked to change pwd after the first access

---

### And then create or first grafana datasource 
![`image_002`](./images_and_diagrams/image_002.png)

### After that let's create a dashboard using the metrics we are generating about the app (i.e. `http_request_duration_ms_bucket`)
![`image_003`](./images_and_diagrams/image_003.png)

![`image_004`](./images_and_diagrams/image_004.png)


