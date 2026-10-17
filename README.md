# Container Security Scanning & Kubernetes Monitoring

A hands-on DevSecOps lab that shows how **container image security**, **Kubernetes deployment**, and **application availability monitoring** fit together in one practical workflow.

A sample NGINX web app is packaged with Docker, scanned for known vulnerabilities with **Trivy**, deployed to a local Kubernetes cluster, and monitored with **Prometheus**, **Blackbox Exporter**, and **Grafana**.

![Docker](https://img.shields.io/badge/Docker-containerized-2496ED?logo=docker&logoColor=white)
![Trivy](https://img.shields.io/badge/Trivy-image%20scanning-1904DA?logo=aqua&logoColor=white)
![Kubernetes](https://img.shields.io/badge/Kubernetes-deployed-326CE5?logo=kubernetes&logoColor=white)
![Prometheus](https://img.shields.io/badge/Prometheus-monitoring-E6522C?logo=prometheus&logoColor=white)
![Grafana](https://img.shields.io/badge/Grafana-dashboards-F46800?logo=grafana&logoColor=white)

---

## Table of Contents

- [Project Goals](#project-goals)
- [Architecture](#architecture)
- [Technology Stack](#technology-stack)
- [Repository Structure](#repository-structure)
- [Quick Start](#quick-start)
- [Step-by-Step Guide](#step-by-step-guide)
  - [1. Prerequisites](#1-prerequisites)
  - [2. Build and Scan the Docker Image](#2-build-and-scan-the-docker-image)
  - [3. Deploy to Kubernetes](#3-deploy-to-kubernetes)
  - [4. Access the Application](#4-access-the-application)
  - [5. Monitor Application Availability](#5-monitor-application-availability)
  - [6. View the Grafana Dashboards](#6-view-the-grafana-dashboards)
  - [7. Alerting](#7-alerting)
  - [8. Jenkins Integration](#8-jenkins-integration)
- [Troubleshooting](#troubleshooting)
- [Current Scope and Future Improvements](#current-scope-and-future-improvements)
- [Key Learnings](#key-learnings)
- [Author](#author)

---

## Project Goals

| Goal | What it demonstrates |
|------|----------------------|
| **Container security** | Identify known vulnerabilities in a Docker image *before* deployment |
| **Container hardening** | Upgrade available Alpine packages during the image build |
| **Kubernetes deployment** | Run the app with multiple replicas behind a Kubernetes Service |
| **Observability** | Track HTTP availability and response time, visualize in Grafana, and alert on failed checks |

---

## Architecture

![Container Security Scanning Pipeline Architecture](images/container-security-architecture.png)

**Flow:** Build → Scan → Deploy → Monitor → Alert

| Stage | Components | Role |
|-------|-----------|------|
| **1. Source Code** | GitHub | Holds the source, Dockerfile, Kubernetes manifests, monitoring configs, and Jenkinsfile |
| **2. CI Pipeline** | Jenkins | Checkout → build image → Trivy scan → security gate (HIGH/CRITICAL) → optional deploy |
| **3. Security Scanning** | Docker, Trivy | Builds `devsecops-web:1.0`, scans it, and saves a report to `reports/` |
| **4. Container Registry** *(optional)* | Docker Hub | Stores the scanned image; not needed for the local setup |
| **5. Kubernetes Deployment** | Docker Desktop Kubernetes | Deployment with 2 replicas, a ClusterIP Service on port 80, accessed via `kubectl port-forward` |
| **6. Monitoring & Alerting** | Blackbox Exporter, Prometheus, Alert Rule | Probes the app every 30s, stores metrics, and evaluates the `DevSecOpsWebDown` rule |
| **7. Dashboards** | Grafana | Pod readiness and HTTP availability dashboards |

> **Note:** Trivy examines the image for known vulnerabilities, while the monitoring stack checks whether the *deployed* application is responding over HTTP. They solve different problems and complement each other.
>
> The Jenkins stage and Docker Hub are shown as part of the intended automation flow. Docker Hub is optional, and Alertmanager is **not configured** in this project. The local scan and monitoring workflow runs independently of Jenkins.

---

## Technology Stack

| Technology | Purpose |
|------------|---------|
| Docker | Build and package the web application |
| NGINX (Alpine) | Serve the sample web page |
| Trivy | Scan the container image for known vulnerabilities |
| Kubernetes | Deploy and manage application replicas |
| Prometheus | Collect and query monitoring metrics |
| Blackbox Exporter | Probe HTTP availability and response time |
| Grafana | Display monitoring dashboards |
| Helm | Install the Kubernetes monitoring stack |
| Jenkins | Pipeline definition for a potential automation workflow |
| Bash | Run the image scanning script |

---

## Repository Structure

```
container-security-scanning-pipeline/
├── images/
│   └── container-security-architecture.png
├── k8s/
│   ├── deployment.yaml
│   └── service.yaml
├── monitoring/
│   ├── devsecops-dashboard.yaml
│   ├── devsecops-http-dashboard.yaml
│   ├── devsecops-web-alerts.yaml
│   └── devsecops-web-probe.yaml
├── reports/
│   └── trivy-report-before-fix.txt
├── scripts/
│   └── scan-image.sh
├── Dockerfile
├── Jenkinsfile
├── index.html
├── PRESENTATION_NOTES.md
└── README.md
```

Generated scan reports are kept out of version control where configured in `.gitignore`. The committed baseline report (`trivy-report-before-fix.txt`) gives a reference for comparing findings before and after image updates.

---

## Quick Start

Already have Docker Desktop (with Kubernetes enabled), Trivy, `kubectl`, and Helm installed? Run:

```bash
# 1. Build and scan
docker build -t devsecops-web:1.0 .
bash scripts/scan-image.sh

# 2. Deploy
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml

# 3. Open the app (keep this terminal running)
kubectl port-forward service/devsecops-web 8081:80
# → http://localhost:8081
```

The monitoring stack is covered in [Step 5](#5-monitor-application-availability).

---

## Step-by-Step Guide

### 1. Prerequisites

Install and configure:

- Docker Desktop
- Trivy
- `kubectl`
- Helm
- A local Kubernetes cluster (e.g. Docker Desktop Kubernetes)
- A browser for the app and dashboards

Verify the tools:

```bash
docker --version
docker ps
trivy --version
kubectl version --client
helm version
```

Make sure Docker Desktop and your local Kubernetes cluster are running before continuing.

### 2. Build and Scan the Docker Image

The Dockerfile uses an NGINX Alpine-based image, upgrades available Alpine packages, and copies in the sample web page.

Build the image:

```bash
docker build -t devsecops-web:1.0 .
```

Confirm it exists:

```bash
docker images | grep devsecops-web
```

Run the scanning script:

```bash
bash scripts/scan-image.sh
```

Review the report:

```bash
tail -n 25 reports/trivy-report.txt
```

Focus on the most serious findings:

```bash
trivy image --severity HIGH,CRITICAL devsecops-web:1.0
```

**Good to know**

- Trivy compares detected packages against its vulnerability database, so results change as the image and database are updated.
- A clean result for HIGH and CRITICAL does **not** mean the image has no vulnerabilities of any severity. Review the actual output rather than assuming a fixed number of findings.

### 3. Deploy to Kubernetes

Check your active context **before** making changes:

```bash
kubectl config current-context
kubectl get nodes
```

Switch to the local cluster if needed:

```bash
kubectl config use-context docker-desktop
```

Apply the resources:

```bash
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
```

Check the rollout:

```bash
kubectl get deployments
kubectl get pods -l app=devsecops-web
kubectl get service devsecops-web
kubectl get endpoints devsecops-web
```

Wait until both replicas are running and ready.

The Deployment maintains the desired number of replicas (and replaces failed Pods), while the Service gives them a stable in-cluster endpoint and load balances traffic across them.

### 4. Access the Application

Forward the Service to a local port:

```bash
kubectl port-forward service/devsecops-web 8081:80
```

Keep this terminal open, then open **<http://localhost:8081>**.

Or check from another terminal:

```bash
curl -I http://localhost:8081
```

An `HTTP 200 OK` response means the endpoint responded successfully to that request.

### 5. Monitor Application Availability

The monitoring configuration uses a Prometheus Blackbox Exporter to check the app's HTTP endpoint.

**How it works**

1. Blackbox Exporter sends an HTTP probe to the Kubernetes Service (every 30 seconds).
2. Prometheus scrapes and stores the probe metrics.
3. Grafana displays availability and response-time data.
4. A Prometheus alert rule evaluates whether the probe has failed.

The stack runs in the `monitoring` namespace. Check its status:

```bash
kubectl get pods -n monitoring
kubectl get probes -n monitoring
kubectl get prometheusrules -n monitoring
```

**Configuration files**

| File | Purpose |
|------|---------|
| `monitoring/devsecops-web-probe.yaml` | HTTP probe definition |
| `monitoring/devsecops-web-alerts.yaml` | `DevSecOpsWebDown` alert rule |
| `monitoring/devsecops-dashboard.yaml` | Kubernetes Pod readiness dashboard |
| `monitoring/devsecops-http-dashboard.yaml` | HTTP availability dashboard |

**Useful Prometheus queries**

```promql
# Did the probe succeed? (1 = yes, 0 = no)
probe_success{job="devsecops-web-http"}

# HTTP status code
probe_http_status_code{job="devsecops-web-http"}

# Probe duration
probe_duration_seconds{job="devsecops-web-http"}
```

### 6. View the Grafana Dashboards

Forward Grafana to your machine:

```bash
kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80
```

Open **<http://localhost:3000>** and sign in with the credentials configured for your local Grafana installation.

> ⚠️ Do not reuse demonstration credentials in production.

Included dashboards cover:

- Kubernetes Pod (replica) readiness
- HTTP availability
- HTTP status code
- HTTP probe response time

Together they connect the Kubernetes deployment state with the application's observed behaviour.

### 7. Alerting

The project defines a PrometheusRule named **`DevSecOpsWebDown`**.

Its expression checks whether the HTTP probe reports failure:

```promql
probe_success{job="devsecops-web-http"} == 0
```

The rule uses a **one-minute pending period** before firing, so a very brief probe failure doesn't trigger it.

**What to expect**

- While the app is healthy, the alert is **inactive**. That is normal.
- When active, it is visible in the Prometheus **Alerts** page.
- Email, Slack, or other notifications require additional **Alertmanager** configuration, which is not part of this project.

### 8. Jenkins Integration

A `Jenkinsfile` is included as a starting point for automating the workflow:

1. Checkout code
2. Build Docker image
3. Run Trivy scan
4. Security gate (check for HIGH/CRITICAL findings)
5. Deploy to Kubernetes *(optional)*

To run it, you need a Jenkins controller and an agent with access to Docker and Trivy. Test the pipeline in that environment before treating it as a working automated CI/CD pipeline.

The local scanning and monitoring workflow can be demonstrated entirely without Jenkins.

---

## Troubleshooting

<details>
<summary><b>Docker is unavailable</b></summary>

Open Docker Desktop, wait for the engine to start, then run:

```bash
docker ps
```
</details>

<details>
<summary><b>Kubernetes Pods are not ready</b></summary>

```bash
kubectl get pods
kubectl describe deployment devsecops-web
```

Inspect Pod events and logs for details.
</details>

<details>
<summary><b>The application does not open locally</b></summary>

```bash
kubectl get service devsecops-web
kubectl get endpoints devsecops-web
```

Make sure the `kubectl port-forward` command is still running.
</details>

<details>
<summary><b>Grafana shows no data</b></summary>

```bash
kubectl get pods -n monitoring
kubectl get probes -n monitoring
kubectl get prometheusrules -n monitoring
```

Give Prometheus time to scrape, and confirm the Blackbox probe target is reachable.
</details>

<details>
<summary><b>The alert is inactive</b></summary>

That's expected while the probe succeeds. Confirm the rule is loaded and that `probe_success` is available before investigating further.
</details>

---

## Current Scope and Future Improvements

**Implemented:** container vulnerability scanning, Kubernetes deployment with 2 replicas, HTTP availability monitoring, Grafana dashboards, and a Prometheus alert rule.

**Possible next steps:**

- [ ] Run and validate the Jenkins pipeline on a configured agent
- [ ] Add automated security checks to pull-request workflows
- [ ] Publish scan reports as build artifacts
- [ ] Configure Alertmanager for external notifications
- [ ] Add more detailed application and Kubernetes resource metrics
- [ ] Introduce additional container security checks and image provenance controls

These are possible extensions, not claims that every capability is already implemented.

---

## Key Learnings

- Building and updating container images
- Using Trivy to identify known image vulnerabilities
- Deploying a multi-replica web application on Kubernetes
- Exposing an application through a Kubernetes Service
- Collecting HTTP probe metrics with Prometheus and Blackbox Exporter
- Building Grafana dashboards and defining a Prometheus alert rule
- Separating implemented components from future automation work

---

## Author

**Samir Maji**
DevOps and Cloud Engineering Portfolio Project

Repository: <https://github.com/samirmaji-tech/container-security-scanning-pipeline>
