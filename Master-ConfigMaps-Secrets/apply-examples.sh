#!/bin/bash

# Script to apply ConfigMap and Secret examples in sequence
# This helps you practice and experiment with different configuration methods

# Set colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}CKAD Journey - ConfigMaps and Secrets Examples${NC}"
echo -e "This script will apply the example manifests in sequence."
echo -e "Press Ctrl+C at any time to stop.\n"

# Function to apply a yaml file and wait for confirmation
apply_and_confirm() {
    local file=$1
    echo -e "\n${GREEN}Applying: ${file}${NC}"
    echo -e "${YELLOW}File content:${NC}"
    cat $file
    echo -e "\n${GREEN}Applying to cluster...${NC}"
    kubectl apply -f $file

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Successfully applied ${file}${NC}"
    else
        echo -e "${RED}Failed to apply ${file}${NC}"
        echo -e "Make sure your Kubernetes cluster is running and kubectl is properly configured."
        exit 1
    fi

    echo -e "\nPress Enter to continue to the next example, or Ctrl+C to exit..."
    read
}

# Create the ConfigMaps
apply_and_confirm 01-basic-configmap.yaml
apply_and_confirm 02-multiline-configmap.yaml

# Create the Secrets
apply_and_confirm 05-basic-secret.yaml

# Apply Pods using ConfigMaps
apply_and_confirm 10-configmap-env-pod.yaml
apply_and_confirm 12-configmap-volume-pod.yaml

# Apply Pods using Secrets
apply_and_confirm 16-secret-volume-pod.yaml

# Apply Advanced Examples
apply_and_confirm 18-projected-volume-pod.yaml

echo -e "${GREEN}All examples have been applied.${NC}"
echo -e "To view the resources created:"

echo -e "${YELLOW}kubectl get pods${NC}"
kubectl get pods

echo -e "\n${YELLOW}kubectl get configmaps${NC}"
kubectl get configmaps

echo -e "\n${YELLOW}kubectl get secrets${NC}"
kubectl get secrets

echo -e "\n${GREEN}To clean up all resources:${NC}"
echo -e "${YELLOW}kubectl delete pods --all${NC}"
echo -e "${YELLOW}kubectl delete configmaps --all${NC}"
echo -e "${YELLOW}kubectl delete secrets --all${NC}"

echo -e "\nWould you like to clean up all created resources now? (y/n)"
read CLEANUP

if [[ $CLEANUP == "y" || $CLEANUP == "Y" ]]; then
    echo -e "${GREEN}Cleaning up resources...${NC}"
    kubectl delete pods --all
    kubectl delete configmaps --all
    kubectl delete secrets --all
    echo -e "${GREEN}Cleanup completed.${NC}"
fi

echo -e "\n${GREEN}Thank you for practicing ConfigMaps and Secrets!${NC}"
echo -e "Continue your CKAD journey at: https://github.com/Salwan-Mohamed/CKAD-journey"
