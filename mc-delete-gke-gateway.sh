#!/bin/bash
PROJECTID=$1
printf "\n***************************************************************************\n***************************************************************************
This script will delete all the resources created for gke gateway. However, it will not delete the load balancers. 
You will have to delete the load balancers from web console manually.\n***************************************************************************\n***************************************************************************\n"


#gcloud alpha container hub ingress disable

#gcloud container hub multi-cluster-services disable --project PROJECTID

gcloud container hub memberships unregister gke-west-1 --gke-cluster=us-west1-a/gke-west-1
gcloud container hub memberships unregister gke-east-1 --gke-cluster=us-east1-b/gke-east-1


gcloud container clusters delete gke-west-1   --zone us-west1-a -q
gcloud container clusters delete gke-east-1   --zone us-east1-b -q


#gcloud compute firewall-rules delete mc-fw-allow-proxies -q
#gcloud compute firewall-rules delete mc-fw-allow-health-check  -q
#gcloud compute firewall-rules delete mc-fw-allow-ssh -q


#gcloud compute networks subnets delete mc-proxy-only-subnet-east1 --region=us-east1 -q
#gcloud compute networks subnets delete mc-gke-subnet3 --region=us-east1 -q
#gcloud compute networks subnets delete mc-gke-subnet2 --region=us-west1 -q
#gcloud compute networks subnets delete mc-proxy-only-subnet-west1 --region=us-west1 -q
#gcloud compute networks subnets delete mc-gke-subnet1 --region=us-west1 -q
#gcloud compute networks delete mc-gateway-gke-network -q
