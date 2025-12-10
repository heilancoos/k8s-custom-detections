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


# Add current user to microk8s group
info "Adding current user ($SUDO_USER) to microk8s group..."
usermod -a -G microk8s "$SUDO_USER"
info "creating kubeconfig"

mkdir -p ~/.kube
chmod 0700 ~/.kube
microk8s config > ~/.kube/config
# Enable essential addons
info "Enabling MicroK8s addons (dns, storage)..."
microk8s status --wait-ready
echo -e "${GREEN}[+] Setting kubectl alias...${NC}"
echo 'alias kubectl="microk8s kubectl"' >> ~/.bashrc
source ~/.bashrc

microk8s enable dns 
microk8s enable storage



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
helm install k8s-metacollector --namespace falco falcosecurity/k8s-metacollector

success "Falco installed successfully!"

# -----------------------------
# Post-Install Notes
# -----------------------------
echo ""
success "Installation complete!"
echo ""
info "Reseting session"
exec $SHELL -l

