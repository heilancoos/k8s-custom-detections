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

info "Triggering Rule: Symlink To Host Files"
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: hostpath-log-demo
spec:
  containers:
  - name: log-demo
    image: alpine:latest
    command: ["tail"]
    args: ["-f", "/dev/null"]
    volumeMounts:
      - mountPath: /var/log/host
        name: log-volume
  volumes:
  - name: log-volume
    hostPath:
      path: /var/log
      type: Directory

EOF
kubectl wait --for=condition=Ready pod/hostpath-log-demo

kubectl exec hostpath-log-demo -- sh -c 'ln -sf /etc/shadow /var/log/host/fake-log'


info "Triggering Rule: Pod Using hostPath to Mount Root Filesystem"
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: root-hostpath-demo
spec:
  containers:
  - name: wvm
    image: alpine:latest
    securityContext:
      privileged: true
    command: ["tail"]
    args: ["-f", "/dev/null"]
    volumeMounts:
    - name: root-volume
      mountPath: /host
  volumes:
  - name: root-volume
    hostPath:
      path: /
      type: Directory
EOF
kubectl wait --for=condition=Ready pod/root-hostpath-demo

info "Triggering Rule:  Container Accessing Mounted Host Root Filesystem"
kubectl exec -it root-hostpath-demo -- ls /host/etc


# -------------------------------------------------

info "Cleaning up..."
kubectl delete pod root-hostpath-demo hostpath-log-demo



