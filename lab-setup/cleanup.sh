#!/usr/bin/env bash
set -euo pipefail

### -----------------------------------------
###  MicroK8s + Falco Teardown Script
### -----------------------------------------
### This script:
### 1. Removes Falco + namespace
### 2. Removes audit webhook + policy files
### 3. Cleans kube-apiserver args
### 4. Stops and resets MicroK8s
### 5. Removes leftover directories
###
### NOTE: This resets the entire MicroK8s cluster.
### -----------------------------------------

RED="\033[0;31m"
GREEN="\033[0;32m"
NC="\033[0m"

APISERVER_FILE="/var/snap/microk8s/current/args/kube-apiserver"
AUDIT_POLICY="/var/snap/microk8s/current/args/audit-policy.yaml"
AUDIT_WEBHOOK="/var/snap/microk8s/current/args/audit-webhook.yaml"
AUDIT_LOG="/var/snap/microk8s/current/logs/audit.log"

echo -e "${GREEN}[+] Removing Falco Helm release (if exists)...${NC}"
if helm list -n falco | grep -q falco; then
    helm uninstall falco -n falco || true
fi

echo -e "${GREEN}[+] Deleting Falco namespace...${NC}"
microk8s kubectl delete namespace falco --ignore-not-found=true

### FULL MICROK8S RESET
### ---------------------------------------------------------

echo -e "${GREEN}[+] Removing MicroK8s snap...${NC}"
sudo snap remove microk8s || true

### ---------------------------------------------------------
### CLEANUP KUBECONFIG + DIRECTORIES
### ---------------------------------------------------------
echo -e "${GREEN}[+] Cleaning kube dirs...${NC}"
rm -rf ~/.kube || true

echo -e "${GREEN}[+] Removing MicroK8s leftover dirs (if any)...${NC}"
sudo rm -rf /var/snap/microk8s
sudo rm -rf /var/lib/microk8s

echo -e "${GREEN}[+] Environment teardown complete.${NC}"
echo "System is now clean. You can rerun the setup script anytime."
