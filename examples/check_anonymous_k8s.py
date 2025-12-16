#!/usr/bin/env python3
import argparse
import requests
import urllib3
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

COMMON_ENDPOINTS = [
    "/", "/version", "/healthz",
    "/api", "/apis", "/metrics", "/openapi/v2",

    # Core API groups/resources
    "/api/v1/pods",
    "/api/v1/namespaces",
    "/api/v1/secrets",
    "/api/v1/configmaps",
    "/api/v1/services",
    "/api/v1/nodes",

    # Workloads
    "/apis/apps/v1/deployments",
    "/apis/apps/v1/daemonsets",
    "/apis/apps/v1/statefulsets",

    # RBAC
    "/apis/rbac.authorization.k8s.io/v1/clusterroles",
    "/apis/rbac.authorization.k8s.io/v1/clusterrolebindings",

    # Events + misc
    "/api/v1/events",
    "/api/v1/endpoints",
]

def check_endpoint(base_url, endpoint):
    url = base_url.rstrip("/") + endpoint
    try:
        response = requests.get(url, verify=False, timeout=5)
        return response.status_code, response.text[:300]
    except Exception as e:
        return None, str(e)

def main():
    parser = argparse.ArgumentParser(
        description="Check which Kubernetes API endpoints are accessible anonymously."
    )
    parser.add_argument("api_server", help="API server URL (e.g., https://127.0.0.1:6443)")
    args = parser.parse_args()

    print(f"\n[*] Testing anonymous access to: {args.api_server}\n")
    print(f"{'Endpoint':50} {'Status'}")
    print("-" * 65)

    for endpoint in COMMON_ENDPOINTS:
        status, _ = check_endpoint(args.api_server, endpoint)
        if status is None:
            print(f"{endpoint:50} ERROR")
        else:
            print(f"{endpoint:50} {status}")

    print("\nLegend:")
    print(" 200 = Accessible anonymously (severe misconfiguration)")
    print(" 403 = Anonymous auth enabled but RBAC blocks access (expected)")
    print(" 401 = Anonymous auth disabled (secure)")
    print(" 404 = Endpoint exists but is not exposed")
    print(" ERROR = Connection issue / invalid API address\n")

if __name__ == "__main__":
    main()
