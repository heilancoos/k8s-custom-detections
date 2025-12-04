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

The goal of this repo is to provide actionable detections and easy reproduction steps for defenders, students, and researchers.


## How to use this repo
