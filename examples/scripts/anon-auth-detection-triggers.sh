#!/usr/bin/env bash
set -e
APISERVER="/var/snap/microk8s/current/args/kube-apiserver"
kubeletAPI="/var/snap/microk8s/current/args/kubelet"

kubectl () {
    microk8s kubectl $*
}

info () {
    echo -e "\e[34m[INFO]\e[0m $1"
}

success () {
    echo -e "\e[32m[SUCCESS]\e[0m $1"
}

error () {
    echo -e "\e[31m[ERROR]\e[0m $1"
    exit 1
}

# Check root or sudo privileges
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root"
fi

info "Configuring API Server to ACCEPT anonymous requests..."
if grep -q "^--anonymous-auth=" "$APISERVER"; then
    info "Updating existing authentication line..."
    sudo sed -i 's/^--anonymous-auth=.*/--anonymous-auth=true/' "$APISERVER"
else
    info "anonymous-auth not found, adding it..."
    echo "--anonymous-auth=true" | sudo tee -a "$APISERVER" >/dev/null
fi

info "Configuring kubelet to accept ACCEPT requests..."
if grep -q "^--anonymous-auth=" "$kubeletAPI"; then
    info "Updating existing authentication line..."
    sudo sed -i 's/^--anonymous-auth=.*/--anonymous-auth=true/' "$kubeletAPI"
else
    info "anonymous-auth not found, adding it..."
    echo "--anonymous-auth=true" | sudo tee -a "$kubeletAPI" >/dev/null
fi

info "Restarting APIs..."
sudo systemctl restart snap.microk8s.daemon-kubelite.service	
sleep 20
info "Installing kubeletctl..."
curl -LO https://github.com/cyberark/kubeletctl/releases/download/v1.13/kubeletctl_linux_amd64 >/dev/null 2>&1 && chmod a+x ./kubeletctl_linux_amd64 && mv ./kubeletctl_linux_amd64 /usr/local/bin/kubeletctl 
info "Triggering Rule(s): Anonymous Request Denied"
curl -k https://127.0.0.1:16443/api/v1/namespaces/default/pods >/dev/null 2>&1
info "Creating vulnerable RBAC Configuration..."
kubectl apply -f allow-anon-pods.yaml

success "Vulnerable environment configured..."

info "Triggering Rule(s): Anonymous Request Allowed and Anonymous Listing of Sensitive Resources"
curl -k https://127.0.0.1:16443/api/v1/namespaces/default/pods >/dev/null 2>&1

info "Triggering Rule(s): Anonymous Pod Creation Attempt"

curl -k -X POST https://127.0.0.1:16443/api/v1/namespaces/default/pods -H "Content-Type: application/json" --data-binary @pod.json >/dev/null 2>&1

info "Triggering Rule(s): Kubelet Remote Exec Attempt"

kubectl run test-pod --image=nginx --restart=Never
kubectl wait --for=condition=ready pod/test-pod --timeout=80s
curl -k -X POST "https://127.0.0.1:10250/run/default/test-pod/test-pod?cmd=ls" >/dev/null 2>&1
kubeletctl exec "cat /etc/shadow" -p test-pod -c test-pod -i
sleep 5

info "Triggering Rule(s): Suspicious Kubelet Enumeration"
kubeletctl pods -i >/dev/null
sleep 5

info "Cleaning up...."
info "Deleting pod artifacts"
kubectl delete pod test-pod
kubectl delete pod anon-poc
info "Deleting pod RBAC"
kubectl delete clusterrole anon-pod-reader
kubectl delete clusterrolebinding anon-pod-reader-binding
info "Configuring API Server to DENY anonymous requests..."
if grep -q "^--anonymous-auth=" "$APISERVER"; then
    info "Updating existing authentication line..."
    sudo sed -i 's/^--anonymous-auth=.*/--anonymous-auth=false/' "$APISERVER"
else
    info "anonymous-auth not found, adding it..."
    echo "--anonymous-auth=true" | sudo tee -a "$APISERVER" >/dev/null
fi

info "Configuring kubelet to DENY anonymous requests..."
if grep -q "^--anonymous-auth=" "$kubeletAPI"; then
    info "Updating existing authentication line..."
    sudo sed -i 's/^--anonymous-auth=.*/--anonymous-auth=false/' "$kubeletAPI"
else
    info "anonymous-auth not found, adding it..."
    echo "--anonymous-auth=true" | sudo tee -a "$kubeletAPI" >/dev/null
fi

info "Restarting APIs..."
sudo systemctl restart snap.microk8s.daemon-kubelite.service	
sleep 20

success "Anonymous test complete"
