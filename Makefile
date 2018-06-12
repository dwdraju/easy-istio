ZIPKIN_POD_NAME=$(shell kubectl -n istio-system get pod -l app=zipkin -o jsonpath='{.items[0].metadata.name}')
SERVICEGRAPH_POD_NAME=$(shell kubectl -n istio-system get pod -l app=servicegraph -o jsonpath='{.items[0].metadata.name}')
GRAFANA_POD_NAME=$(shell kubectl -n istio-system get pod -l app=grafana -o jsonpath='{.items[0].metadata.name}')

requirement:
	kubectl api-versions | grep admissionregistration

deploy:
	# Install base Istio
	kubectl apply -f install/kubernetes/istio.yaml
	# Create signed cert/key pair
	./install/kubernetes/webhook-create-signed-cert.sh --service istio-sidecar-injector --namespace istio-system --secret sidecar-injector-certs
	# Install the sidecar injection configmap.
	kubectl apply -f install/kubernetes/istio-sidecar-injector-configmap-release.yaml
	cat install/kubernetes/istio-sidecar-injector.yaml | ./install/kubernetes/webhook-patch-ca-bundle.sh > install/kubernetes/istio-sidecar-injector-with-ca-bundle.yaml
	kubectl apply -f install/kubernetes/istio-sidecar-injector-with-ca-bundle.yaml
	kubectl label namespace default istio-injection=enabled

install-addons:
	# install tracing, monitoring, servicegraph addons
	kubectl apply -f install/kubernetes/addons/prometheus.yaml
	kubectl apply -f install/kubernetes/addons/grafana.yaml
	kubectl apply -f install/kubernetes/addons/zipkin.yaml
	kubectl apply -f install/kubernetes/addons/servicegraph.yaml
	# set GOOGLE_APPLICATION_CREDENTIALS on install/kubernetes/addons/zipkin-to-stackdriver.yaml
	#kubectl apply -f install/kubernetes/addons/zipkin-to-stackdriver.yaml

confirm:
	# Confirm if sidecar injector webhook is running
	kubectl -n istio-system get deployment -listio=sidecar-injector
	# Check istio enabled
	kubectl get namespace -L istio-injection

monitor:
	$(shell kubectl -n istio-system port-forward $(ZIPKIN_POD_NAME) 9411:9411 & kubectl -n istio-system port-forward $(SERVICEGRAPH_POD_NAME) 8088:8088 & kubectl -n istio-system port-forward $(GRAFANA_POD_NAME) 3000:3000)

destroy:
	kubectl delete -f install/kubernetes/istio-sidecar-injector-with-ca-bundle.yaml
	kubectl -n istio-system delete secret sidecar-injector-certs
	kubectl delete csr istio-sidecar-injector.istio-system
	kubectl label namespace default istio-injection-

