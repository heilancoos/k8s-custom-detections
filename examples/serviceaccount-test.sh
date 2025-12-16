#!/usr/bin/env bash

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

info "Configuring service account..."
kubectl create serviceaccount app-sa --dry-run=client -o yaml | kubectl apply -f -

cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: app-editor
  namespace: default
rules:
- apiGroups: ["", "apps", "batch"]
  resources: ["pods", "deployments", "cronjobs"]
  verbs: ["get", "list", "watch", "create", "update"]
- apiGroups: [""]
  resources: ["pods/exec"]
  verbs: ["create"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: app-editor-binding
  namespace: default
subjects:
- kind: ServiceAccount
  name: app-sa
  namespace: default
roleRef:
  kind: Role
  name: app-editor
  apiGroup: rbac.authorization.k8s.io
EOF

info "Deploying pod..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: testy-app
  namespace: default
spec:
  serviceAccountName: app-sa
  containers:
  - name: alpine
    image: alpine
    command: ["sleep", "3600"]
EOF

kubectl wait --for=condition=Ready pod/testy-app
success "Environment set up!"

# -------------------------------------------------
info "Testing rule: Pod ServiceAccount Token File Access"
kubectl exec testy-app -- cat /var/run/secrets/kubernetes.io/serviceaccount/token >/dev/null

# -------------------------------------------------
info "Testing rule: CLI Token Usage by Local Process"
kubectl exec testy-app -- sh -c "
apk add curl >/dev/null &&
TOKEN=\$(cat /var/run/secrets/kubernetes.io/serviceaccount/token) &&
curl -k https://kubernetes.default.svc/api/v1/namespaces/default/pods \
  -H \"Authorization: Bearer \$TOKEN\" >/dev/null 2>&1c
"

# -------------------------------------------------
info "Testing rule: Privileged or Host-Level Container Creation"
kubectl exec testy-app -- sh -c "
apk add curl >/dev/null &&
TOKEN=\$(cat /var/run/secrets/kubernetes.io/serviceaccount/token) &&
curl -k -X POST \
  -H \"Authorization: Bearer \$TOKEN\" \
  -H \"Content-Type: application/json\" \
  -d '{
    \"apiVersion\": \"v1\",
    \"kind\": \"Pod\",
    \"metadata\": { \"name\": \"priv-shell\" },
    \"spec\": {
      \"containers\": [{
        \"name\": \"pwn\",
        \"image\": \"alpine\",
        \"command\": [\"/bin/sh\", \"-c\", \"sleep 999999\"],
        \"securityContext\": { \"privileged\": true }
      }]
    }
  }' \
  https://kubernetes.default.svc/api/v1/namespaces/default/pods >/dev/null 2>&1
"

success "Rules tested"

# -------------------------------------------------
info "Cleaning up..."
kubectl delete pod testy-app priv-shell --ignore-not-found
kubectl delete serviceaccount app-sa --ignore-not-found
kubectl delete role app-editor --ignore-not-found
kubectl delete rolebinding app-editor-binding --ignore-not-found
