#!/usr/bin/env bash
#
# install-microk8s-helm-falco.sh
#
# A simple bootstrap script to install:
#   - MicroK8s (lightweight Kubernetes)
#   - Helm (package manager)
#   - Falco (runtime security engine)
#
# Designed for Ubuntu-based systems.
# Requires sudo privileges.
#
APISERVER="/var/snap/microk8s/current/args/kube-apiserver"


set -e  # exit immediately on error

# -----------------------------
# Helper Functions
# -----------------------------

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

# -----------------------------
# Install MicroK8s
# -----------------------------
info "Installing MicroK8s..."

snap install microk8s --classic || error "Failed to install MicroK8s"
microk8s disable ha-cluster --force
microk8s status --wait-ready




microk8s enable dns 
microk8s enable storage
info "Waiting for API server + addons to fully stabilize..."
sleep 10
microk8s status --wait-ready
# Add current user to microk8s group
info "Adding current user ($SUDO_USER) to microk8s group..."
usermod -a -G microk8s "$SUDO_USER"
info "creating kubeconfig"

mkdir -p /home/$SUDO_USER/.kube
chown -R "$SUDO_USER":"$SUDO_USER" /home/$SUDO_USER/.kube

chmod 0700 /home/$SUDO_USER/.kube
microk8s config > /home/$SUDO_USER/.kube/config
chmod 0700 ~/.kube
microk8s config > ~/.kube/config
# Enable essential addons
info "Enabling MicroK8s addons (dns, storage)..."
microk8s status --wait-ready
echo -e "${GREEN}[+] Setting kubectl alias...${NC}"
echo 'alias kubectl="microk8s kubectl"' >> /home/$SUDO_USER/.bashrc
source /home/$SUDO_USER/.bashrc


success "MicroK8s installed successfully."

# -----------------------------
# Install Helm
# -----------------------------
info "Installing Helm..."

sudo snap install helm --classic || error "Failed to install Helm"

success "Helm installed successfully."



# -----------------------------
# Install Falco via Helm
# -----------------------------
info "Adding Falco Helm repository..."
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo update


# Install Falco
info "Installing Falco via Helm..."

if [[ -f values.yaml ]]; then
    helm install --replace falco --namespace falco --create-namespace --set tty=true falcosecurity/falco \
        --namespace falco \
        --set tty=true \
        -f values.yaml
else
    info "No values.yaml found; installing Falco with default values."
    helm install --replace falco --namespace falco --create-namespace --set tty=true falcosecurity/falco
fi
success "Falco installed successfully!"


info "Configuring k8saudit..."
helm install k8s-metacollector --namespace falco falcosecurity/k8s-metacollector

info "Setting up audit webhook config..."
webhookIP=$(microk8s kubectl get svc falco-k8saudit-webhook -n falco -o jsonpath='{.spec.clusterIP}')
webhookPort=$(microk8s kubectl get svc falco-k8saudit-webhook -n falco -o jsonpath='{.spec.ports[0].port}')
sed -i "s|server: http://.*:.*\/k8s-audit|server: http://$webhookIP:$webhookPort/k8s-audit|" webhook-config.yaml
cp webhook-config.yaml /var/snap/microk8s/current/args/
cp audit-policy.yaml /var/snap/microk8s/current/args/

info "Configuraing API Server..."
if grep -q "^--authorization-mode=" "$APISERVER"; then
    info "Updating existing authorization-mode line..."
    sudo sed -i 's/^--authorization-mode=.*/--authorization-mode=Node,RBAC/' "$APISERVER"
else
    info "authorization-mode not found, adding it..."
    echo "--authorization-mode=Node,RBAC" | sudo tee -a "$APISERVER" >/dev/null
fi

sudo sed -i '/--audit-policy-file/d' "$APISERVER"
sudo sed -i '/--audit-log-path/d' "$APISERVER"
sudo sed -i '/--audit-webhook-config-file/d' "$APISERVER"

sudo tee -a "$APISERVER" >/dev/null <<EOF

# Audit Configuration
--audit-policy-file=/var/snap/microk8s/current/args/audit-policy.yaml
--audit-log-path=/var/snap/microk8s/common/var/log/kube-apiserver-audit.log
--audit-webhook-config-file=/var/snap/microk8s/current/args/webhook-config.yaml
EOF

echo "[INFO] Restarting MicroK8s API server..."
sudo systemctl restart snap.microk8s.daemon-kubelite.service	


# -----------------------------
# Post-Install Notes
# -----------------------------
echo ""
success "Installation complete!"
echo ""
info "Reseting session"
exec $SHELL -l

