#!/bin/bash
PROJECTNAME=$1
PROJECTNUMBER=$2
PRIVATE_KEY_FILE=key.pem
CSR_FILE=csr.txt
CONFIG_FILE=sslconfig.txt
CERTIFICATE_FILE=cert.pem
CLUSTER_VERSION=1.21.6-gke.1500


if [[ -z $PROJECTNAME ]]; then
    echo " Project Name is missing"
    exit
else 
    echo $PROJECTNAME
fi



echo -e "\n*********************************************************\n"
echo  -e "Enabling services....................\n"

echo -e "\n*********************************************************\n"
echo  "Project ID is..... "$PROJECTNAME
gcloud config set project ${PROJECTNAME}

gcloud services enable \
    container.googleapis.com \
    gkehub.googleapis.com \
    multiclusterservicediscovery.googleapis.com \
    multiclusteringress.googleapis.com \
    trafficdirector.googleapis.com \
    --project=${PROJECTNAME}



echo -e "\n*********************************************************\n"
echo  -e "Creating network mc-gateway-gke-network.....................\n"
gcloud compute networks create mc-gateway-gke-network --subnet-mode=custom

echo -e "Creating proxy only subnet us-west1................................\n"
gcloud compute networks subnets create mc-proxy-only-subnet \
    --purpose=REGIONAL_MANAGED_PROXY \
    --role=ACTIVE \
    --region=us-west1 \
    --network=mc-gateway-gke-network \
    --range=10.145.0.0/23

echo -e "Creating gke  subnet1.. us-west1 .....................................\n"
gcloud compute networks subnets create mc-gke-subnet1 \
    --purpose=PRIVATE \
    --role=ACTIVE \
    --region=us-west1 \
    --network=mc-gateway-gke-network \
    --range=10.142.0.0/16 \
    --secondary-range my-pods-1=10.143.0.0/16,my-services-1=10.144.0.0/20 \
    --enable-private-ip-google-access

echo -e "Creating gke  subnet2. us-west1......................................\n"
gcloud compute networks subnets create mc-gke-subnet2 \
    --purpose=PRIVATE \
    --role=ACTIVE \
    --region=us-west1 \
    --network=mc-gateway-gke-network \
    --range=10.152.0.0/16 \
    --secondary-range my-pods-2=10.153.0.0/16,my-services-2=10.154.0.0/20 \
    --enable-private-ip-google-access


echo -e "Creating proxy only subnet us-east1................................\n"
gcloud compute networks subnets create mc-proxy-only-subnet \
    --purpose=REGIONAL_MANAGED_PROXY \
    --role=ACTIVE \
    --region=us-east1 \
    --network=mc-gateway-gke-network \
    --range=10.165.0.0/23


echo -e "Creating gke  subnet3  us-east1 .......................................\n"
gcloud compute networks subnets create mc-gke-subnet3 \
    --purpose=PRIVATE \
    --role=ACTIVE \
    --region=us-east1 \
    --network=mc-gateway-gke-network \
    --range=10.162.0.0/16 \
    --secondary-range my-pods-3=10.163.0.0/16,my-services-3=10.164.0.0/20 \
    --enable-private-ip-google-access



echo -e "Creating firewall rules to allow tcp:22...........................\n"
gcloud compute firewall-rules create mc-fw-allow-ssh \
    --network=mc-gateway-gke-network \
    --action=allow \
    --direction=ingress \
    --rules=tcp:22

echo -e "Creating firewall health checks................................\n"
gcloud compute firewall-rules create mc-fw-allow-health-check \
    --network=mc-gateway-gke-network \
    --action=allow \
    --direction=ingress \
    --source-ranges=130.211.0.0/22,35.191.0.0/16 \
    --rules=tcp

echo -e  "Creating firewall rules to allow tcp:80 443 8080 traffic.......\n"
gcloud compute firewall-rules create mc-fw-allow-proxies \
  --network=mc-gateway-gke-network \
  --action=allow \
  --direction=ingress \
  --source-ranges=0.0.0.0/0 \
  --rules=tcp:80,tcp:443,tcp:8080



echo -e "\n*********************************************************\n"
read -p "Press enter to continue creating resources.........."
echo -e "\nCreating GKE cluster gke-west1..........................................\n"



gcloud beta container --project "${PROJECTNAME}" clusters create "gke-west-1" \
  --zone "us-west1-a" \
  --no-enable-basic-auth \
  --cluster-version "${CLUSTER_VERSION}" \
  --release-channel "regular" \
  --machine-type "e2-small" \
  --image-type "COS_CONTAINERD" \
  --disk-type "pd-standard" \
  --disk-size "50" \
  --metadata disable-legacy-endpoints=true \
  --scopes "https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/trace.append" \
  --num-nodes "3" \
  --enable-stackdriver-kubernetes \
  --enable-private-nodes \
  --master-ipv4-cidr "172.16.0.32/28" \
  --enable-master-global-access \
  --enable-ip-alias \
  --network "projects/${PROJECTNAME}/global/networks/mc-gateway-gke-network" \
  --subnetwork "projects/${PROJECTNAME}/regions/us-west1/subnetworks/mc-gke-subnet1" \
  --cluster-secondary-range-name "my-pods-1" \
  --services-secondary-range-name "my-services-1" \
  --no-enable-intra-node-visibility \
  --default-max-pods-per-node "110" \
  --no-enable-master-authorized-networks \
  --addons HorizontalPodAutoscaling,HttpLoadBalancing,GcePersistentDiskCsiDriver \
  --enable-autoupgrade \
  --enable-autorepair \
  --max-surge-upgrade 1 \
  --max-unavailable-upgrade 0 \
  --enable-shielded-nodes \
  --node-locations "us-west1-a" \
  --workload-pool=${PROJECTNAME}.svc.id.goog

echo -e "\nCreating GKE cluster gke-east1..........................................\n"
gcloud beta container --project "${PROJECTNAME}" clusters create "gke-east-1" \
  --zone "us-east1-b" \
  --no-enable-basic-auth \
  --cluster-version "${CLUSTER_VERSION}" \
  --release-channel "regular" \
  --machine-type "e2-small" \
  --image-type "COS_CONTAINERD" \
  --disk-type "pd-standard" \
  --disk-size "50" \
  --metadata disable-legacy-endpoints=true \
  --scopes "https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/trace.append" \
  --num-nodes "3" \
  --enable-stackdriver-kubernetes \
  --enable-private-nodes \
  --master-ipv4-cidr "173.16.0.32/28" \
  --enable-master-global-access \
  --enable-ip-alias \
  --network "projects/${PROJECTNAME}/global/networks/mc-gateway-gke-network" \
  --subnetwork "projects/${PROJECTNAME}/regions/us-east1/subnetworks/mc-gke-subnet3" \
  --cluster-secondary-range-name "my-pods-3" \
  --services-secondary-range-name "my-services-3" \
  --no-enable-intra-node-visibility \
  --default-max-pods-per-node "110" \
  --no-enable-master-authorized-networks \
  --addons HorizontalPodAutoscaling,HttpLoadBalancing,GcePersistentDiskCsiDriver \
  --enable-autoupgrade \
  --enable-autorepair \
  --max-surge-upgrade 1 \
  --max-unavailable-upgrade 0 \
  --enable-shielded-nodes \
  --node-locations "us-east1-b" \
  --workload-pool=${PROJECTNAME}.svc.id.goog



echo -e "\nRunning get-gredentials ......................................\n"
gcloud container clusters get-credentials gke-west-1 --zone us-west1-a
gcloud container clusters get-credentials gke-east-1 --zone us-east1-b

echo -e "\nRunning kubectl config rename-context ......................................\n"
kubectl config rename-context gke_${PROJECTNAME}_us-west1-a_gke-west-1 gke-west-1
kubectl config rename-context gke_${PROJECTNAME}_us-east1-b_gke-east-1 gke-east-1

echo -e "\nRegistering clusters with GKE hub......................................\n"
gcloud alpha container hub memberships register gke-west-1 \
     --gke-cluster us-west1-a/gke-west-1 \
     --enable-workload-identity \
     --project=${PROJECTNAME}

gcloud alpha container hub memberships register gke-east-1 \
     --gke-cluster us-east1-b/gke-east-1 \
     --enable-workload-identity \
     --project=${PROJECTNAME}

echo -e "\nConfirming GKE hub memberships......................................\n"
gcloud alpha container hub memberships list --project=${PROJECTNAME}

echo -e "\nEnable multicluster services.....................................\n"
gcloud container hub multi-cluster-services enable \
    --project ${PROJECTNAME}

echo -e "\nGrant IAM permissions for  multicluster services.....................................\n"
gcloud projects add-iam-policy-binding ${PROJECTNAME} \
     --member "serviceAccount:${PROJECTNAME}.svc.id.goog[gke-mcs/gke-mcs-importer]" \
     --role "roles/compute.networkViewer" \
     --project=${PROJECTNAME}

echo -e "\nConfirm  multicluster services enabled .....................................\n"
gcloud container hub multi-cluster-services describe --project=${PROJECTNAME}

echo -e "\nInstalling Gateway API  CRDs .....................................\n"
kubectl kustomize "github.com/kubernetes-sigs/gateway-api/config/crd?ref=v0.3.0" | kubectl apply -f -

echo -e "\nEnable multicluster gatway controller .....................................\n"
gcloud alpha container hub ingress enable \
    --config-membership=/projects/${PROJECTNAME}/locations/global/memberships/gke-west-1 \
    --project=${PROJECTNAME}

echo -e "\nConfirm multicluster gatway controller .....................................\n"
gcloud alpha container hub ingress describe --project=${PROJECTNAME}

echo -e "\nGrant IAM permissions required by gateway controller .....................................\n"
gcloud projects add-iam-policy-binding ${PROJECTNAME} \
     --member "serviceAccount:service-${PROJECTNUMBER}@gcp-sa-multiclusteringress.iam.gserviceaccount.com" \
     --role "roles/container.admin" \
     --project=${PROJECTNAME}



kubectl get gatewayclasses --context=gke-west-1









