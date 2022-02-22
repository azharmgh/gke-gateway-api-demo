#!/bin/bash
#PROJECTNAME=$1
#PROJECTNUMBER=$2


kubectl apply --context gke-west-1 -f https://raw.githubusercontent.com/GoogleCloudPlatform/gke-networking-recipes/main/gateway/gke-gateway-controller/multi-cluster-gateway/store.yaml
#kubectl apply --context gke-west-2 -f https://raw.githubusercontent.com/GoogleCloudPlatform/gke-networking-recipes/main/gateway/gke-gateway-controller/multi-cluster-gateway/store.yaml
kubectl apply --context gke-east-1 -f https://raw.githubusercontent.com/GoogleCloudPlatform/gke-networking-recipes/main/gateway/gke-gateway-controller/multi-cluster-gateway/store.yaml


kubectl apply -f store-west-service.yaml --context gke-west-1
kubectl apply -f store-east-service.yaml --context gke-east-1 --namespace store

kubectl get serviceexports --context gke-west-1 --namespace store
kubectl get serviceexports --context gke-east-1 --namespace store



kubectl get serviceimports --context gke-west-1 --namespace store
kubectl get serviceimports --context gke-east-1 --namespace store



kubectl apply -f external-http-gateway.yaml --context gke-west-1 --namespace store

kubectl apply -f public-store-route.yaml --context gke-west-1 --namespace store


kubectl describe gateway external-http --context gke-west-1 --namespace store

kubectl get gateway external-http -o=jsonpath="{.status.addresses[0].value}" --context gke-west-1 --namespace store