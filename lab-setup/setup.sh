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
    error "This script must be run as root. Try: sudo ./install-microk8s-helm-falco.sh"
fi

# -----------------------------
# Install MicroK8s
# -----------------------------
info "Installing MicroK8s..."

snap install microk8s --classic || error "Failed to install MicroK8s"

# Add current user to microk8s group
info "Adding current user ($SUDO_USER) to microk8s group..."
usermod -a -G microk8s "$SUDO_USER"
chown -f -R "$SUDO_USER" ~/.kube || true

# Enable essential addons
info "Enabling MicroK8s addons (dns, storage)..."
microk8s status --wait-ready
microk8s enable dns storage

success "MicroK8s installed successfully."

# -----------------------------
# Install Helm
# -----------------------------
info "Installing Helm..."

curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash || \
    error "Failed to install Helm"

success "Helm installed successfully."

# -----------------------------
# Install Falco via Helm
# -----------------------------
info "Adding Falco Helm repository..."
microk8s helm repo add falcosecurity https://falcosecurity.github.io/charts
microk8s helm repo update

# Create namespace
info "Creating 'falco' namespace..."
microk8s kubectl create namespace falco --dry-run=ignore -o yaml | microk8s kubectl apply -f -

# Install Falco
info "Installing Falco via Helm..."

if [[ -f values.yaml ]]; then
    microk8s helm upgrade --install falco falcosecurity/falco \
        --namespace falco \
        --set tty=true \
        -f values.yaml
else
    info "No values.yaml found; installing Falco with default values."
    microk8s helm upgrade --install falco falcosecurity/falco \
        --namespace falco \
        --set tty=true
fi

success "Falco installed successfully!"

# -----------------------------
# Post-Install Notes
# -----------------------------
echo ""
success "Installation complete!"
echo ""
echo "Log out and back in (or run 'newgrp microk8s') to apply group changes."
echo "Check Falco logs:"
echo ""
echo "    microk8s kubectl -n falco logs -l app=falco"
echo ""

