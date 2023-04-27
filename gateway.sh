#Create gke cluster with gateway api enabled
gcloud container clusters create gateway-test --gateway-api=standard --enable-l4-ilb-subsetting --zone us-central1-a  --node-locations us-central1-a --num-nodes=2 --spot
gcloud container clusters get-credentials gateway-test --region us-central1-a --project cwsdemo
kubectl get gatewayclass

#Deploy the internal gateway
kubectl apply -f manifests/gateway-internal.yaml
kubectl get gateway
kubectl describe gateways.gateway.networking.k8s.io internal-http

#Deploy/update the namespaces
kubectl apply -f manifests/namespace.yaml
kubectl label namespaces default shared-gateway-access=true --overwrite=true

#Deploy the default-nginx-backend
kubectl apply -f manifests/backendconfig-default-backend.yaml
kubectl apply -f manifests/nginx-default-backend.yaml

#Deploy the demo applications
kubectl apply -f manifests/store.yaml
kubectl get pod -n store-en
kubectl get svc -n store-en
kubectl get pod -n store-de
kubectl get svc -n store-de
kubectl get pod -n store-canary
kubectl get svc -n store-canary

#Apply internal HTTP route
kubectl apply -f manifests/route-internal-default-backend.yaml
kubectl describe httproute route-internal-default-backend -n default
kubectl apply -f manifests/route-internal-store-en.yaml
kubectl describe httproute route-internal-store-en -n store-en
kubectl apply -f manifests/route-internal-store-de.yaml
kubectl describe httproute route-internal-store-de -n store-de

#Create a compute instance in the same vpc, test by sending traffic to your application from a VM
#Create instance
gcloud compute instances create gateway-test-vm --machine-type e2-small --tags http-server --zone us-central1-a
#Get the virtual ip address of the internal gateway by running the following command
kubectl get gateways.gateway.networking.k8s.io internal-http -o=jsonpath="{.status.addresses[0].value}"
#SSH into the instance and test the application
curl -vvv -H "host: store.example.com" http://INTERNAL_GATEWAY_IP
curl -vvv -H "host: store.example.com" http://INTERNAL_GATEWAY_IP/en
curl -vvv -H "host: store.example.com" http://INTERNAL_GATEWAY_IP/de
#To test header based routing:
curl -vvv -H "host: store.example.com" -H "env:canary" http://INTERNAL_GATEWAY_IP/canary

#Deploy the external gateway
kubectl apply -f manifests/gateway-external.yaml
kubectl describe gateways.gateway.networking.k8s.io external-http
kubectl get gateways.gateway.networking.k8s.io external-http -o=jsonpath="{.status.addresses[0].value}"

#Apply external HTTP route
kubectl apply -f manifests/route-external-default-backend.yaml
kubectl describe httproute route-external-default-backend -n default
kubectl apply -f manifests/route-external-store-en.yaml
kubectl describe httproute route-external-store-en -n store-en
kubectl apply -f manifests/route-external-store-de.yaml
kubectl describe httproute route-external-store-de -n store-de
kubectl apply -f manifests/route-external-store-canary.yaml
kubectl describe httproute route-external-store-canary -n store-canary

#Get the virtual ip address of the internal gateway by running the following command
kubectl get gateways.gateway.networking.k8s.io external-http -o=jsonpath="{.status.addresses[0].value}"
#Open you browser and try accessing
http://EXTERNAL_GATEWAY_IP
http://EXTERNAL_GATEWAY_IP/en
http://EXTERNAL_GATEWAY_IP/de
#To test header based routing, fire up your Postman, add header with name=env and value=canary and hit the below url:
http://EXTERNAL_GATEWAY_IP/canary