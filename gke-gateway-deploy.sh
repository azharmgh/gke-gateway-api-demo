#!/bin/bash
PROJECTNAME=$1
PRIVATE_KEY_FILE=key.pem
CSR_FILE=csr.txt
CONFIG_FILE=sslconfig.txt
CERTIFICATE_FILE=cert.pem



if [[ -z $PROJECTNAME ]]; then
    echo " Project Name is missing"
    exit
else 
    echo $PROJECTNAME
fi

echo -e "\n*********************************************************\n"
echo  "Project ID is..... "$PROJECTNAME
gcloud config set project ${PROJECTNAME}
gcloud config set compute/region us-west1
gcloud config set compute/zone us-west1-a
gcloud services enable container.googleapis.com
echo -e "\n*********************************************************\n"
echo  -e "Creating network gateway-gke-network.....................\n"
gcloud compute networks create gateway-gke-network --subnet-mode=custom

echo -e "Creating proxy only subnet................................\n"
gcloud compute networks subnets create proxy-only-subnet \
    --purpose=INTERNAL_HTTPS_LOAD_BALANCER \
    --role=ACTIVE \
    --region=us-west1 \
    --network=gateway-gke-network \
    --range=10.130.0.0/23

echo -e "Creating gke  subnet.......................................\n"
gcloud compute networks subnets create gke-subnet \
    --purpose=PRIVATE \
    --role=ACTIVE \
    --region=us-west1 \
    --network=gateway-gke-network \
    --range=10.132.0.0/16 \
    --secondary-range my-pods-2=10.133.0.0/16,my-services-2=10.134.0.0/20 \
    --enable-private-ip-google-access

echo -e "Creating firewall rules to allow tcp:22...........................\n"
gcloud compute firewall-rules create fw-allow-ssh \
    --network=gateway-gke-network \
    --action=allow \
    --direction=ingress \
    --rules=tcp:22

echo -e "Creating firewall health checks................................\n"
gcloud compute firewall-rules create fw-allow-health-check \
    --network=gateway-gke-network \
    --action=allow \
    --direction=ingress \
    --source-ranges=130.211.0.0/22,35.191.0.0/16 \
    --rules=tcp

echo -e  "Creating firewall rules to allow tcp:80 443 8080 traffic.......\n"
gcloud compute firewall-rules create fw-allow-proxies \
  --network=gateway-gke-network \
  --action=allow \
  --direction=ingress \
  --source-ranges=0.0.0.0/0 \
  --rules=tcp:80,tcp:443,tcp:8080

echo -e "\n*********************************************************\n"
read -p "Press enter to continue creating resources.........."
echo -e "\nCreating GKE cluster ..........................................\n"

gcloud beta container --project "${PROJECTNAME}" clusters create "gateway-cluster" \
  --zone "us-west1-a" \
  --no-enable-basic-auth \
  --cluster-version "1.20.6-gke.1000" \
  --release-channel "regular" \
  --machine-type "e2-small" \
  --image-type "COS_CONTAINERD" \
  --disk-type "pd-standard" \
  --disk-size "100" \
  --metadata disable-legacy-endpoints=true \
  --scopes "https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/trace.append" \
  --num-nodes "3" \
  --enable-stackdriver-kubernetes \
  --enable-private-nodes \
  --master-ipv4-cidr "172.16.0.32/28" \
  --enable-master-global-access \
  --enable-ip-alias \
  --network "projects/${PROJECTNAME}/global/networks/gateway-gke-network" \
  --subnetwork "projects/${PROJECTNAME}/regions/us-west1/subnetworks/gke-subnet" \
  --cluster-secondary-range-name "my-pods-2" \
  --services-secondary-range-name "my-services-2" \
  --no-enable-intra-node-visibility \
  --default-max-pods-per-node "110" \
  --no-enable-master-authorized-networks \
  --addons HorizontalPodAutoscaling,HttpLoadBalancing,GcePersistentDiskCsiDriver \
  --enable-autoupgrade \
  --enable-autorepair \
  --max-surge-upgrade 1 \
  --max-unavailable-upgrade 0 \
  --enable-shielded-nodes \
  --node-locations "us-west1-a"



echo -e "\nRunning get-gredentials ......................................\n"
gcloud container clusters get-credentials gateway-cluster --zone us-west1-a

echo -e "\nInstalling the gateway api CRDs..................................\n"
kubectl kustomize "github.com/kubernetes-sigs/gateway-api/config/crd?ref=v0.3.0" | kubectl apply -f -

sleep 3m

echo -e "\nGetting gatewayclass.......\n"
kubectl get gatewayclass

echo -e "\n*********************************************************\n"
read -p "Press enter to continue.........."


GTWCOUNT=$(kubectl get gatewayclass | grep networking.gke.io/gateway|  wc -l | awk '{print $1}')
if [[ $GTWCOUNT -ge 2 ]]; then 
     echo -e "\nGKE gateway classes installed \n"
else 
     echo -e "\nUnable to install  gateway class .... exiting...\n"
     exit
fi

echo -e "\nCreating internal gateway...........\n"
kubectl apply -f gateway.yaml

sleep 3m

echo -e "\nValidating internal gateway............\n"
kubectl describe gateway internal-http

sleep 2m

echo -e "\n*********************************************************\n"
read -p "Press enter to continue.........."

GTWSUCCESS=$(kubectl describe gateway internal-http | grep "SYNC on default/internal-http was a success" | grep success | wc -l)

if [[ $GTWSUCCESS -eq 1 ]]; then 
     echo -e "\nInternal gateway created successfully..... \n"
else 
     echo -e "\nUnable to validate  internal gateway .... exiting...\n"
     exit
fi

echo -e "\nDeploying the demo applications..........\n"
kubectl apply -f https://raw.githubusercontent.com/GoogleCloudPlatform/gke-networking-recipes/master/gateway/gke-gateway-controller/app/store.yaml
sleep 1m

echo -e "\n*********************************************************\n"
read -p "Press enter to continue.........."

PODS=$(kubectl get pods | grep Running |  wc -l)
if [[ $PODS -eq 6 ]]; then 
     echo -e "6 pods deployed successfully..... \n"
else 
     echo -e "Unable to deploy pods .... exiting...\n"
     exit
fi

echo -e "Checking deployed services...........\n"
kubectl get service

SVCS=$(kubectl get service | grep store | wc -l)
if [[ $SVCS -eq 3 ]]; then 
     echo -e "3 services deployed successfully..... \n"
else 
     echo -e "Unable to validate services .... exiting...\n"
     exit
fi

echo -e "Deploying the HTTPRoute for application pods....\n"
kubectl apply -f store-route.yaml
echo -e "Getting IP of internal gateway...................\n"

sleep 1m
echo -e "\n*********************************************************\n"
read -p "Press enter to continue.........."

INTERNALIP=$(kubectl get gateway internal-http -o=jsonpath="{.status.addresses[0].value}")
if [[ -z $INTERNALIP ]]; then
    echo -e " Internal IP not found .... exiting \n"
    exit
else 
    echo -e "Internal IP is = " $INTERNALIP
fi

echo -e "\nPlease note down the Internal IP You will use it to test using curl command from test vm. \n"

echo -e "\n*********************************************************\n"
read -p "\nPress enter to continue creating a test-vm for testing.........."

echo -e "\nCreating test-vm........\n"
gcloud beta compute --project=$PROJECTNAME instances create test-vm --zone=us-west1-a --machine-type=e2-micro --subnet=gke-subnet --network-tier=PREMIUM --maintenance-policy=MIGRATE --service-account=556649436052-compute@developer.gserviceaccount.com --scopes=https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/trace.append --image=debian-10-buster-v20210609 --image-project=debian-cloud --boot-disk-size=10GB --boot-disk-type=pd-balanced --boot-disk-device-name=test-vm --no-shielded-secure-boot --shielded-vtpm --shielded-integrity-monitoring --reservation-affinity=any

IP=$(kubectl get gateway internal-http -o=jsonpath="{.status.addresses[0].value}")
echo -e "Run the command to ssh to the vm: \n"
echo -e "gcloud beta compute ssh --zone us-west1-a test-vm  --project $PROJECTNAME"
echo -e '\n Once you ssh then run the curl commands to check the pods\n'

printf "\ncurl -H \"host: store.example.com\" $IP\n"
printf "\ncurl -H \"host: store.example.com\" $IP/de\n"
printf "\ncurl -H \"host: store.example.com\"  -H \"env: canary \" $IP \n"

read -p "Press enter to continue to deploy shared gateway the site application .........."


kubectl apply -f https://raw.githubusercontent.com/GoogleCloudPlatform/gke-networking-recipes/master/gateway/gke-gateway-controller/app/site.yaml

echo -e "\n deploying site-route.yaml ...... \n"
kubectl apply -f site-route.yaml

kubectl describe httproute site

echo -e "\nRun the command to ssh to the vm: \n"
echo -e "gcloud beta compute ssh --zone us-west1-a test-vm  --project $PROJECTNAME"
echo -e '\n Once you ssh then run following curl commands to check the pods:\n'

printf "\ncurl -H \"host: store.example.com\" $IP\n"
printf "\ncurl -H \"host: site.example.com\" $IP\n"

echo -e "\n*********************************************************\n"
read -p "Press enter to continue to deploy external gateway .........."

echo -e "\nCreating global self signed ssl certs ............\n"

openssl genrsa -out ./$PRIVATE_KEY_FILE 2048

openssl req -new -key ./$PRIVATE_KEY_FILE \
    -out ./$CSR_FILE \
    -config ./$CONFIG_FILE


openssl x509 -req \
    -signkey ./$PRIVATE_KEY_FILE \
    -in ./$CSR_FILE \
    -out ./$CERTIFICATE_FILE \
    -days 100



gcloud compute ssl-certificates create store-example-com \
    --certificate=cert.pem \
    --private-key=key.pem \
    --global

echo -e "\nGlobal ssl cert created: store-example-com ............\n"
gcloud compute ssl-certificates list --global

echo -e "\n*********************************************************\n"
read -p "Press enter to deploy the external-gateway.yaml  ....."
kubectl apply -f external-gateway.yaml
echo -e "\n*********************************************************\n"
read -p "Press enter to deploy the route store-external-route.yaml ....."

kubectl apply -f store-external-route.yaml

printf "\n Run this command to check for external IP: kubectl get gateway external-http -o=jsonpath=\"{.status.addresses[0].value}\" \n"

echo -e "\n*********************************************************\n"
read -p "Press enter to continue.....it may take several minutes for the external gateway to deploy...."

sleep 15m

EIP=$(kubectl get gateway external-http -o=jsonpath="{.status.addresses[0].value}")

if [[ -z $EIP ]]; then
    echo -e "\nExternal IP not found .... exiting \n"
    exit
else 
    echo -e "\nExternal IP is = " $EIP
fi

echo "Running curl https://store.example.com --resolve store.example.com:443:$EIP --cacert $CERTIFICATE_FILE -v"

curl https://store.example.com --resolve store.example.com:443:$EIP --cacert $CERTIFICATE_FILE -v

echo -e "\n****************************************************************"
echo -e "\nAll resources created. Play with resources and once done, run the delete-gke-gateway.sh scirpt to clean up all resources.\n"
echo -e "\n****************************************************************"