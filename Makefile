YQ:=$(shell which yq)
JQ:=$(shell which jq)
KUBECTL:=$(shell which kubectl)
DOCKER:=$(shell which docker)
HELM:=$(shell which helm)
KIND:=$(shell which kind)
PARENT_CHART_VALUES_FILE:="deploy-charts/values.yaml"
DEPLOYMENT_CHART_VALUES_FILE:="deploy-charts/charts/deployment/values.yaml"

DEFAULT_CLUSTER_NAME:=$(shell ${YQ} e '.defaultClusterName' ${PARENT_CHART_VALUES_FILE})
CLUSTER_NAME:=$(shell ${YQ} e '.clusterName' ${PARENT_CHART_VALUES_FILE})

DEPLOYMENT_RELEASE_NAME:=$(shell ${YQ} e '.deployemntReleaseName' ${PARENT_CHART_VALUES_FILE})
DEPLOYMENT_NAME:=$(shell ${YQ} e '.deployment.app.name' ${PARENT_CHART_VALUES_FILE})-deployment
APP_NAME:=$(shell ${YQ} e '.deployment.app.name' ${PARENT_CHART_VALUES_FILE})
APP_TAG:=$(shell ${YQ} e '.deployment.app.tag' ${PARENT_CHART_VALUES_FILE})
DEPLOY_NAMESPACE:=$(shell ${YQ} e '.deployment.namespace' ${DEPLOYMENT_CHART_VALUES_FILE})
PROMETHEUS_NAMESPACE:=$(shell ${YQ} e '.prometheusNamespace' ${PARENT_CHART_VALUES_FILE})
GRAFANA_NAMESPACE:=$(shell ${YQ} e '.grafanaNamespace' ${PARENT_CHART_VALUES_FILE})
IMAGE_NAME_TAG:=$(APP_NAME):$(APP_TAG)
FULLY_QUALIFIED_IMAGE_URL:=$(ARTIFACT_REGISTRY)$(IMAGE_NAME_TAG)

print_mk_var:
	@echo "YQ: [$(YQ)]"
	@echo "KUBECTL: [$(KUBECTL)]"
	@echo "DOCKER: [$(DOCKER)]"
	@echo "PARENT_CHART_VALUES_FILE: [$(PARENT_CHART_VALUES_FILE)]"
	@echo "DEPLOYMENT_RELEASE_NAME: [$(DEPLOYMENT_RELEASE_NAME)]"
	@echo "DEFAULT_CLUSTER_NAME: [$(DEFAULT_CLUSTER_NAME)]"
	@echo "CLUSTER_NAME: [$(CLUSTER_NAME)]"
	@echo "APP_NAME: [$(APP_NAME)]"
	@echo "APP_TAG: [$(APP_TAG)]"
	@echo "DEPLOY_NAMESPACE: [$(DEPLOY_NAMESPACE)]"
	@echo "IMAGE_NAME_TAG: [$(IMAGE_NAME_TAG)]"
	@echo "FULLY_QUALIFIED_IMAGE_URL: [$(FULLY_QUALIFIED_IMAGE_URL)]"

create_deploy_namespace:
	$(KUBECTL) create namespace $(DEPLOY_NAMESPACE)

delete_deploy_namespace:
	$(KUBECTL) delete namespace $(DEPLOY_NAMESPACE)

build:
	$(DOCKER) build \
	--pull --no-cache \
	-t $(IMAGE_NAME_TAG) \
	-f ./src/Dockerfile \
	./src

tag: 
	$(DOCKER) tag \
	$(IMAGE_NAME_TAG) \
	$(FULLY_QUALIFIED_IMAGE_URL)

load_image:
	$(KIND) load docker-image --name $(CLUSTER_NAME) $(FULLY_QUALIFIED_IMAGE_URL) 

build_tag_push_image:
	$(MAKE) build tag load_image

deployment_manifest:
	$(HELM) template --debug \
	-f deploy-charts/values.yaml \
	--set 'deployment.enabled=true' \
	--set 'strategy.enabled=false' \
	deploy-charts	

deployment_install:
	$(HELM) upgrade --install \
	--debug \
	-n $(DEPLOY_NAMESPACE) \
	-f deploy-charts/values.yaml \
	--set 'deployment.enabled=true' \
	--set 'strategy.enabled=false' \
	$(DEPLOYMENT_RELEASE_NAME) ./deploy-charts

deployment_uninstall:
	$(HELM) uninstall $(DEPLOYMENT_RELEASE_NAME) 

cluster_start:
	$(KIND) create cluster

cluster_delete:
	$(KIND) delete cluster --name $(CLUSTER_NAME)
	$(KIND) delete cluster --name $(DEFAULT_CLUSTER_NAME)

create_cluster:
	$(KIND) create \
	cluster --config=infra/cluster.yaml \
	--name $(CLUSTER_NAME)

set_context_cluster:
	$(KUBECTL) config set-context $(CLUSTER_NAME)

cluster_info:
	$(KUBECTL) cluster-info --context kind-$(CLUSTER_NAME)

ingress_controller_install:
	$(KUBECTL) apply -f infra/ingress_controller.yaml
	@sleep 30
	$(MAKE) wait_for_ingress_controller
  
wait_for_ingress_controller:
	$(KUBECTL) wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s


# prometheus

wait_for_prom_operator_deploy:
	$(KUBECTL) wait \
	deployment -n $(PROMETHEUS_NAMESPACE) \
	prometheus-operator \
	--for condition=Available=True \
	--timeout=300s

wait_for_prom_statefulset: 
	@sleep 5
	$(KUBECTL) rollout \
	-n $(PROMETHEUS_NAMESPACE) \
	status --watch --timeout=300s \
	statefulset/prometheus-prometheus

wait_for_prom_pods: 
	$(KUBECTL) wait \
	-n $(PROMETHEUS_NAMESPACE) \
	--for condition=ready \
	--timeout=300s \
	pod -l prometheus=prometheus 

prometheus-operator-install: 
	$(KUBECTL) create -n $(PROMETHEUS_NAMESPACE) -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/master/bundle.yaml

prometheus-rbac-install: 
	$(KUBECTL) apply -n $(PROMETHEUS_NAMESPACE) -f infra/prometheus/prom_rbac.yaml

prometheus-install: 
	$(KUBECTL) apply -n $(PROMETHEUS_NAMESPACE) -f infra/prometheus/prometheus.yaml

prometheus-svc-install: 
	$(KUBECTL) apply -n $(PROMETHEUS_NAMESPACE) -f infra/prometheus/prom_svc.yaml
	$(KUBECTL) patch svc prometheus \
	-n $(PROMETHEUS_NAMESPACE) \
	--type=json -p='[{"op": "add", "path": "/spec/selector/prometheus", "value": "prometheus"}]'
	$(KUBECTL) patch svc prometheus \
	-n $(PROMETHEUS_NAMESPACE) \
	--type=json -p='[{"op": "remove", "path": "/spec/selector/app"}]'

prometheus-ui-ingress-install: 
	$(KUBECTL) apply -n $(PROMETHEUS_NAMESPACE) -f infra/prometheus/prometheus_ingress.yaml

prometheus-self-monitor-install: 
	$(KUBECTL) apply -n $(PROMETHEUS_NAMESPACE) -f infra/prometheus/prometheus_service_self_monitor.yaml

prometheus-app-monitor-install: 
	$(KUBECTL) apply -n $(PROMETHEUS_NAMESPACE) -f infra/prometheus/prometheus_service_app_monitor.yaml

prometheus-install-all: 
	$(MAKE) prometheus-operator-install \
	prometheus-rbac-install \
	prometheus-install \
	wait_for_prom_operator_deploy \
	wait_for_prom_statefulset \
	wait_for_prom_pods \
	prometheus-svc-install \
	prometheus-ui-ingress-install \
	prometheus-self-monitor-install \
	prometheus-app-monitor-install 

# prometheus-app-monitor-install

prometheus-operator-uninstall: 
	$(KUBECTL) delete \
	--ignore-not-found \
	-n $(PROMETHEUS_NAMESPACE) \
	-f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/master/bundle.yaml

prometheus-rbac-uninstall: 
	$(KUBECTL) delete \
	--ignore-not-found \
	-n $(PROMETHEUS_NAMESPACE) \
	-f infra/prometheus/prom_rbac.yaml

prometheus-uninstall: 
	$(KUBECTL) delete \
	--ignore-not-found \
	-n $(PROMETHEUS_NAMESPACE) \
	-f infra/prometheus/prometheus.yaml

prometheus-svc-uninstall: 
	$(KUBECTL) delete \
	--ignore-not-found \
	-n $(PROMETHEUS_NAMESPACE) \
	-f infra/prometheus/prom_svc.yaml

prometheus-service-monitor-uninstall: 
	$(KUBECTL) delete \
	--ignore-not-found \
	-n $(PROMETHEUS_NAMESPACE) \
	-f infra/prometheus/prometheus_service_monitor.yaml

prometheus-ui-ingress-uninstall: 
	$(KUBECTL) delete \
	--ignore-not-found \
	-n $(PROMETHEUS_NAMESPACE) \
	-f infra/prometheus/prometheus_ingress.yaml

prometheus-uninstall-all: 
	$(MAKE) prometheus-service-monitor-uninstall \
	prometheus-svc-uninstall \
	prometheus-ui-ingress-uninstall \
	prometheus-uninstall \
	prometheus-rbac-uninstall \
	prometheus-operator-uninstall
# prometheus

grafana-install:
	$(KUBECTL) apply -n $(GRAFANA_NAMESPACE) -f infra/grafana/grafana.yaml

grafana-uninstall:
	$(KUBECTL) delete -n $(GRAFANA_NAMESPACE) -f infra/grafana/grafana.yaml
		
all:
	$(MAKE) print_mk_var \
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

# create_deploy_namespace \

clean_up: cluster_delete


