# k8s-custom-detections
## Overview
This repository contains a curated collection of Falco detection rules, audit policies, sample attack manifests, and configuration files designed to detect real-world Kubernetes attack techniques.

These detections were developed as part of a larger research project on Kubernetes security, covering techniques such as:

- Anonymous API access
- Overly permissive RBAC
- Service account token abuse
- CoreDNS manipulation
- ETCD unauthorized access
- hostPath container escapes
- Malicious admission controllers
- Kubernetes “Golden Ticket” certificate forgery

**Blog Post**: https://heilancoos.github.io/research/2025/12/16/kubernetes.html
### `falco/rules/`
Contains **custom Falco rules** grouped by attack surface (RBAC, CoreDNS, etcd, admission controllers, etc.).

Each file focuses on a specific attack class and is intended to be:
- Readable
- Auditable
- Tunable for real environments

To test specific rules:
Edit lab_setup/values.yaml and replace the `customRules: {}` block.

Then reload with:

```bash
helm upgrade --namespace falco falco falcosecurity/falco -f values.yaml	
```

### `examples/`
Contains **reproducible test scripts** that intentionally trigger the detections.

These scripts:
- Simulate attacker behavior
- Can be run individually or chained

## Usage

### Installation
```bash
git clone https://github.com/heilancoos/k8s-custom-detections.git
cd k8s-custom-detections
chmod +x ./lab_setup/setup.sh && ./lab_setup/setup.sh
```
### Running Individual Tests
Example:

```bash
./examples/rbac-rules-test.sh
```

## Clean Up
```bash
./lab_setup/clean.sh
```
