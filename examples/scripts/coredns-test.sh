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
# -------------------------------------------------

info "Triggering Rule: Unusual CoreDNS Access Attempt"
kubectl get configmap/coredns -n kube-system >/dev/null

info "Triggering Rule: CoreDNS ConfigMap Modified"
info "Triggering Rule: CoreDNS Rewrite Rule Added"
kubectl patch configmap/coredns -n kube-system \
  --type=merge \
  -p '{
    "data": {
      "Corefile": ".:53 {\n    rewrite name example.com evil.com\n    forward . /etc/resolv.conf\n}\n"
    }
  }'

# -------------------------------------------------

info "Cleaning up..."

kubectl patch configmap/coredns -n kube-system \
  --type=merge \
  -p '{
    "data": {
      "Corefile": ".:53 {\n        errors\n        health {\n          lameduck 5s\n        }\n        ready\n        log . {\n          class error\n        }\n        kubernetes cluster.local in-addr.arpa ip6.arpa {\n          pods insecure\n          fallthrough in-addr.arpa ip6.arpa\n        }\n        prometheus :9153\n        forward . /etc/resolv.conf\n        cache 30\n        loop\n        reload\n        loadbalance\n    }\n"
    }
  }'



