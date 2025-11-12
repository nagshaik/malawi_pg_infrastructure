#!/bin/bash

# Script to fix AWS Load Balancer Controller VPC configuration
# Adds --aws-vpc-id and --cluster-name flags to the controller deployment

set -e

echo "=================================================="
echo "Fixing AWS Load Balancer Controller Configuration"
echo "=================================================="

CLUSTER_NAME="malawi-pg-azampay-eks-cluster"
VPC_ID="vpc-077eae864604eac3a"
REGION="eu-central-1"

echo ""
echo "Cluster: $CLUSTER_NAME"
echo "VPC ID: $VPC_ID"
echo "Region: $REGION"
echo ""

# Update the controller deployment with required flags
echo "Updating controller deployment with VPC ID and cluster name..."
kubectl set env deployment/aws-load-balancer-controller \
  -n kube-system \
  AWS_REGION=$REGION

kubectl patch deployment aws-load-balancer-controller \
  -n kube-system \
  --type='json' \
  -p='[
    {
      "op": "add",
      "path": "/spec/template/spec/containers/0/args/-",
      "value": "--aws-vpc-id='$VPC_ID'"
    },
    {
      "op": "add",
      "path": "/spec/template/spec/containers/0/args/-",
      "value": "--aws-region='$REGION'"
    }
  ]'

echo ""
echo "Waiting for controller to restart..."
kubectl rollout status deployment/aws-load-balancer-controller -n kube-system --timeout=120s

echo ""
echo "Checking controller logs..."
sleep 5
kubectl logs -n kube-system deployment/aws-load-balancer-controller --tail=20

echo ""
echo "Checking controller status..."
kubectl get deployment -n kube-system aws-load-balancer-controller

echo ""
echo "Checking Ingress resources..."
kubectl get ingress --all-namespaces

echo ""
echo "=================================================="
echo "Fix applied! Monitor the ADDRESS column for ALB creation."
echo "Run: kubectl get ingress --all-namespaces -w"
echo "=================================================="
