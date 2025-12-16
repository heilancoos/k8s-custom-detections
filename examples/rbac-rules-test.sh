#!/usr/bin/env bash
set -e


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


info "Testing rules: ClusterRole Binding to Anonymous User, ClusterRole Binding to Cluster Admin, RBAC Wildcard Permissions Detected, Namespaced SA Bound to ClusterRole"

cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: anon-user-binding
subjects:
- kind: User
  name: system:anonymous
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: view
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: cluster-admin-binding
subjects:
- kind: User
  name: evil-user
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: wildcard-clusterrole
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["*"]
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: evil-sa
  namespace: default
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: evil-sa-rolebinding
  namespace: default
subjects:
- kind: ServiceAccount
  name: evil-sa
  namespace: default
roleRef:
  kind: ClusterRole
  name: view
  apiGroup: rbac.authorization.k8s.io
EOF

success "RBAC Configured!"

info "cleaning up...."
kubectl delete clusterrolebinding anon-user-binding
kubectl delete clusterrolebinding cluster-admin-binding
kubectl delete rolebinding evil-sa-rolebinding
kubectl delete clusterrole wildcard-clusterrole
kubectl delete serviceaccount evil-sa

success "RBAC Configuration cleaned up"


