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

ETCDCTL_API=3
ETCDCTL_ENDPOINTS="https://127.0.0.1:12379"

ETCDCTL_CACERT="/var/snap/microk8s/current/certs/ca.crt"
ETCDCTL_CERT="/var/snap/microk8s/current/certs/server.crt"
ETCDCTL_KEY="/var/snap/microk8s/current/certs/server.key"

info "installing pre reqs"
sudo apt install golang-go -y >/dev/null
sudo apt install etcd-client -y >/dev/null
git clone https://github.com/nccgroup/kubetcd >/dev/null
cd kubetcd

info "editing source files to work with microk8s..."
grep -rlI '2379' ./cmd/ | xargs sed -i 's/2379/12379/g'
grep -rlI '/etc/kubernetes/pki/etcd/ca.crt' ./cmd/ | xargs sed -i 's|/etc/kubernetes/pki/etcd/ca.crt|/var/snap/microk8s/current/certs/ca.crt|g'
grep -rlI '/etc/kubernetes/pki/etcd/server.key' ./cmd/ | xargs sed -i 's|/etc/kubernetes/pki/etcd/server.key|/var/snap/microk8s/current/certs/server.key|g'
grep -rlI '/etc/kubernetes/pki/etcd/server.crt' ./cmd/ | xargs sed -i 's|/etc/kubernetes/pki/etcd/server.crt|/var/snap/microk8s/current/certs/server.crt|g'

go build -buildvcs=false . >/dev/null


# -------------------------------------------------

info "Triggering Rule: Suspicious Etcd Access"
etcdctl get --prefix "" --keys-only >/dev/null

info "Triggering Rule: ETCD Pod Tampering"
kubectl run ghostpod --image=alpine
./kubetcd create pod ghostpod-attacker -t ghostpod --fake-ns -n ghost 

info "Triggering Rule: ETCD read attempt from unusual source detected"
etcdctl get /registry/pods --prefix --keys-only >/dev/null 2>&1

info "Triggering Rule: ETCD Snapshot Created"
etcdctl snapshot save snapshot.db >/dev/null 2>&1

info "Triggering Rule: ETCD Registry Deletion"
etcdctl del /registry/pods/ghost/ghostpod-attacker >/dev/null 2>&1

# -------------------------------------------------

info "Cleaning up..."
cd ..
rm -rf ./kubetcd/
kubectl delete pod ghostpod
