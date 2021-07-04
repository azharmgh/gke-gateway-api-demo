#!/bin/bash

printf "\n***************************************************************************\n***************************************************************************
This script will delete all the resources created for gke gateway. However, it will not delete the load balancers. 
You will have to delete the load balancers from web console manually.\n***************************************************************************\n***************************************************************************\n"

gcloud config set compute/zone us-west1-a
gcloud container clusters delete gateway-cluster   --zone us-west1-a -q
gcloud compute instances delete test-vm --zone=us-west1-a -q


fwlist=$(gcloud compute url-maps list | awk '{print $1}')
# Set space as the delimiter
rr=$( echo $fwlist | sed "s/NAME/ /")
echo $rr 
b=($rr)
echo "There are ${#b[*]} load balancers that need to be deleted."
gcloud config set compute/region us-west1

for vv in "${b[@]}";
do
  printf "load balancers to manually delete  $vv\n"
  
done

read -p "Press enter after you have manually deleted the load balancers from web console."


firewallrules=$(gcloud compute firewall-rules list | grep gke-network | awk '{print $1}')

gcloud compute firewall-rules delete -q $firewallrules



neglist=$(gcloud compute network-endpoint-groups list | awk '{print $1}')

nn=$(echo $neglist | sed "s/NAME/ /")
echo $nn
narr=($nn)
echo "There are ${#narr[*]} network endpoints that will be deleted."
for nev in "${narr[@]}";
do
  printf "deleting neg  $nev\n"
  gcloud compute network-endpoint-groups delete -q $nev  
done



gcloud compute firewall-rules delete fw-allow-proxies -q
gcloud compute firewall-rules delete fw-allow-health-check  -q
gcloud compute firewall-rules delete fw-allow-ssh -q
gcloud compute networks subnets delete proxy-only-subnet --region=us-west1 -q
gcloud compute networks subnets delete gke-subnet --region=us-west1 -q
gcloud compute networks delete gateway-gke-network -q

gcloud compute ssl-certificates delete store-example-com --global -q