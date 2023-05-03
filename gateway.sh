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
kubectl apply -f manifests/bookstore.yaml
kubectl get pod -n bookstore-en
kubectl get svc -n bookstore-en
kubectl get pod -n bookstore-de
kubectl get svc -n bookstore-de
kubectl get pod -n bookstore-canary
kubectl get svc -n bookstore-canary

#Apply internal HTTP route
kubectl apply -f manifests/route-internal-default-backend.yaml
kubectl describe httproute route-internal-default-backend -n default
kubectl apply -f manifests/route-internal-bookstore-en.yaml
kubectl describe httproute route-internal-bookstore-en -n bookstore-en
kubectl apply -f manifests/route-internal-bookstore-de.yaml
kubectl describe httproute route-internal-bookstore-de -n bookstore-de
kubectl apply -f manifests/route-internal-bookstore-canary.yaml
kubectl describe httproute route-internal-bookstore-canary -n bookstore-de

#Create a compute instance in the same vpc, test by sending traffic to your application from a VM
#Create instance
gcloud compute instances create gateway-test-vm --machine-type e2-small --tags http-server --zone us-central1-a
#Get the virtual ip address of the internal gateway by running the following command
kubectl get gateways.gateway.networking.k8s.io internal-http -o=jsonpath="{.status.addresses[0].value}"
#SSH into the instance and test the application
curl -vvv -H "host: bookstore.example.com" http://INTERNAL_GATEWAY_IP
curl -vvv -H "host: bookstore.example.com" http://INTERNAL_GATEWAY_IP/en
curl -vvv -H "host: bookstore.example.com" http://INTERNAL_GATEWAY_IP/de
#To test header based routing:
curl -vvv -H "host: bookstore.example.com" -H "env:canary" http://INTERNAL_GATEWAY_IP/canary

#Deploy the external gateway
kubectl apply -f manifests/gateway-external.yaml
kubectl describe gateways.gateway.networking.k8s.io external-http
kubectl get gateways.gateway.networking.k8s.io external-http -o=jsonpath="{.status.addresses[0].value}"

#Apply external HTTP route
kubectl apply -f manifests/route-external-default-backend.yaml
kubectl describe httproute route-external-default-backend -n default
kubectl apply -f manifests/route-external-bookstore-en.yaml
kubectl describe httproute route-external-bookstore-en -n bookstore-en
kubectl apply -f manifests/route-external-bookstore-de.yaml
kubectl describe httproute route-external-bookstore-de -n bookstore-de
kubectl apply -f manifests/route-external-bookstore-canary.yaml
kubectl describe httproute route-external-bookstore-canary -n bookstore-canary

#Get the virtual ip address of the internal gateway by running the following command
kubectl get gateways.gateway.networking.k8s.io external-http -o=jsonpath="{.status.addresses[0].value}"
#Open you browser and try accessing
http://EXTERNAL_GATEWAY_IP
http://EXTERNAL_GATEWAY_IP/en
http://EXTERNAL_GATEWAY_IP/de
#To test header based routing, fire up your Postman/any API testing tool, add header with name=env and value=canary and hit the below url:
http://EXTERNAL_GATEWAY_IP/