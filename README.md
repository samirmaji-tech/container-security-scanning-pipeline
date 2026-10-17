# Container Security Scanning & Kubernetes Monitoring

A hands-on DevSecOps lab exploring how container image security, Kubernetes deployment, and application availability monitoring fit together in a practical workflow.

The project packages a sample web application with Docker, checks the image for known vulnerabilities using Trivy, deploys the application to a local Kubernetes cluster, and monitors HTTP availability using Prometheus, Blackbox Exporter, and Grafana.

## Project Goals

This project was built to practise and demonstrate four important DevOps and security tasks:

- **Container security:** identify known vulnerabilities in a Docker image before deployment.
- **Container hardening:** update available Alpine Linux packages in the image build.
- **Kubernetes deployment:** run the web application with multiple replicas and expose it through a Kubernetes Service.
- **Observability:** track HTTP availability and response time, visualize results in Grafana, and define an alert for failed availability checks.

## Architecture

![Container Security Scanning Pipeline Architecture](images/container-security-architecture.png)

```text
                    APPLICATION DELIVERY
                    ─────────────────────

Source Code + Dockerfile
          |
          v
    Docker Image
          |
          v
   Trivy Image Scan
          |
          v
  Vulnerability Report
          |
          v
  Review and Remediation
          |
          v
 Kubernetes Deployment
      (2 Replicas)
          |
          v
   Kubernetes Service
          |
          v
    Sample Web App


                  MONITORING AND ALERTING
                  ───────────────────────

 Kubernetes Web Service
          |
          v
   Blackbox Exporter
   (HTTP Availability)
          |
          v
      Prometheus
   (Metrics Collection)
          |
          +------------------+
          |                  |
          v                  v
      Grafana           Alert Rule
   (Dashboards)      (DevSecOpsWebDown)
```

The security scan and monitoring components serve different purposes. Trivy examines the image for known vulnerabilities, while the monitoring stack checks whether the deployed web application responds successfully over HTTP.

## Technology Stack

| Technology | Purpose |
|---|---|
| Docker | Build and package the web application |
| NGINX | Serve the sample web page |
| Trivy | Scan the container image for known vulnerabilities |
| Kubernetes | Deploy and manage application replicas |
| Prometheus | Collect and query monitoring metrics |
| Blackbox Exporter | Probe HTTP availability and response time |
| Grafana | Display monitoring dashboards |
| Helm | Install the Kubernetes monitoring stack |
| Jenkins | Pipeline definition for a potential automation workflow |
| Bash | Run the image scanning script |

## Repository Structure

```text
container-security-scanning-pipeline/
├── Dockerfile
├── Jenkinsfile
├── README.md
├── PRESENTATION_NOTES.md
├── index.html
├── scripts/
│   └── scan-image.sh
├── k8s/
│   ├── deployment.yaml
│   └── service.yaml
├── monitoring/
│   ├── devsecops-dashboard.yaml
│   ├── devsecops-http-dashboard.yaml
│   ├── devsecops-web-alerts.yaml
│   └── devsecops-web-probe.yaml
└── reports/
    └── trivy-report-before-fix.txt
```

Generated scan reports are kept out of version control where configured in `.gitignore`. The committed baseline report provides a reference for comparing findings before and after image updates.

## 1. Prerequisites

Install and configure the following tools:

- Docker Desktop
- Trivy
- `kubectl`
- Helm
- A local Kubernetes cluster, such as Docker Desktop Kubernetes
- A browser to access the web application and dashboards

Verify the tools:

```bash
docker --version
docker ps
trivy --version
kubectl version --client
helm version
```

Ensure Docker Desktop and your local Kubernetes cluster are running before proceeding.

## 2. Build and Scan the Docker Image

The Dockerfile uses an NGINX Alpine-based image, upgrades available Alpine packages, and copies the sample web page into the image.

Build the image:

```bash
docker build -t devsecops-web:1.0 .
```

Confirm that it exists:

```bash
docker images | grep devsecops-web
```

Run the project scanning script:

```bash
bash scripts/scan-image.sh
```

Review the generated report:

```bash
tail -n 25 reports/trivy-report.txt
```

To focus on HIGH and CRITICAL vulnerabilities:

```bash
trivy image --severity HIGH,CRITICAL devsecops-web:1.0
```

Trivy compares detected packages against its vulnerability database. Results can change as the image and vulnerability database are updated.

A clean result for the selected severity levels does not necessarily mean the image has no vulnerabilities of any severity. Review the actual output rather than assuming a fixed number of findings.

## 3. Deploy to Kubernetes

Check the active Kubernetes context before making changes:

```bash
kubectl config current-context
kubectl get nodes
```

For the local Docker Desktop cluster, select its context if needed:

```bash
kubectl config use-context docker-desktop
```

Apply the application resources:

```bash
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
```

Check the deployment and Pods:

```bash
kubectl get deployments
kubectl get pods -l app=devsecops-web
kubectl get service devsecops-web
kubectl get endpoints devsecops-web
```

Wait until both replicas are running and ready.

The Deployment maintains the desired number of application replicas. The Service provides a stable endpoint for accessing them within the cluster.

## 4. Access the Application

Forward the Kubernetes Service to a local port:

```bash
kubectl port-forward service/devsecops-web 8081:80
```

Keep this terminal open while using the forwarded connection.

Open the application at:

http://localhost:8081

Alternatively, verify the HTTP response from another terminal:

```bash
curl -I http://localhost:8081
```

An HTTP `200 OK` response indicates that the application endpoint responded successfully to that request.

## 5. Monitor Application Availability

The monitoring configuration uses a Prometheus Blackbox Exporter to check the application's HTTP endpoint.

The monitoring workflow is:

1. Blackbox Exporter sends an HTTP probe to the Kubernetes Service.
2. Prometheus collects the probe metrics.
3. Grafana displays the resulting availability and response-time data.
4. A Prometheus alert rule evaluates whether the HTTP probe has failed.

The monitoring stack is installed in the `monitoring` namespace.

Check its status:

```bash
kubectl get pods -n monitoring
kubectl get probes -n monitoring
kubectl get prometheusrules -n monitoring
```

The HTTP probe configuration is stored in:

`monitoring/devsecops-web-probe.yaml`

The alert rule is stored in:

`monitoring/devsecops-web-alerts.yaml`

The dashboard configurations are stored in the `monitoring/` directory.

### Useful Prometheus Queries

Check whether the HTTP probe succeeds:

```promql
probe_success{job="devsecops-web-http"}
```

Check the HTTP status code:

```promql
probe_http_status_code{job="devsecops-web-http"}
```

Check probe duration:

```promql
probe_duration_seconds{job="devsecops-web-http"}
```

A `probe_success` value of `1` indicates a successful probe; `0` indicates a failed probe.

## 6. View the Grafana Dashboards

Forward the Grafana Service to your machine:

```bash
kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80
```

Open:

http://localhost:3000

Use the local lab credentials configured for your Grafana installation. Do not reuse demonstration credentials in production.

The project includes dashboards for:

- Application replica readiness
- HTTP availability
- HTTP status code
- HTTP probe response time

The dashboards help connect the Kubernetes deployment state with the observed behaviour of the application.

## 7. Alerting

The project includes a PrometheusRule named `DevSecOpsWebDown`.

Its expression checks whether the HTTP probe reports failure:

```promql
probe_success{job="devsecops-web-http"} == 0
```

The rule uses a one-minute pending period before the alert becomes active, helping avoid reacting to a very brief probe failure.

The rule is intended to demonstrate alert evaluation. An inactive alert while the application is healthy is expected. External email, Slack, or other notification delivery requires additional Alertmanager configuration.

## 8. Jenkins Integration

A `Jenkinsfile` is included as a starting point for integrating image building, Trivy scanning, and a security gate into a Jenkins workflow.

To execute it, a Jenkins controller and a suitably configured agent must have access to Docker and Trivy. The pipeline should be tested in that environment before describing it as a working automated CI/CD pipeline.

The local image scan and Kubernetes monitoring workflow can be demonstrated independently of Jenkins.

## 9. Troubleshooting

**Docker is unavailable**

Open Docker Desktop and wait for the engine to start, then check:

```bash
docker ps
```

**Kubernetes Pods are not ready**

```bash
kubectl get pods
kubectl describe deployment devsecops-web
```

Inspect the relevant Pod events and logs if necessary.

**The application does not open locally**

Check the Service and endpoints:

```bash
kubectl get service devsecops-web
kubectl get endpoints devsecops-web
```

Ensure the port-forward command is still running.

**Grafana has no monitoring data**

```bash
kubectl get pods -n monitoring
kubectl get probes -n monitoring
kubectl get prometheusrules -n monitoring
```

Allow time for Prometheus to scrape metrics, and confirm that the Blackbox probe target is reachable.

**The alert is inactive**

An inactive alert is normal when the HTTP probe is succeeding. Confirm that the rule is loaded and the probe metric is available before troubleshooting alert behaviour.

## 10. Current Scope and Future Improvements

The current lab brings together container vulnerability scanning, Kubernetes application deployment, HTTP availability monitoring, dashboards, and an alert rule.

Potential next steps include:

- Execute and validate the Jenkins pipeline on a configured agent.
- Add automated security checks to pull-request workflows.
- Publish scan reports as build artifacts.
- Configure Alertmanager for external notifications.
- Add more detailed application and Kubernetes resource metrics.
- Introduce additional container security checks and image provenance controls.

These are possible extensions rather than claims that every capability is already implemented.

## Key Learnings

This project provided hands-on practice with:

- Building and updating container images.
- Using Trivy to identify known image vulnerabilities.
- Deploying a multi-replica web application on Kubernetes.
- Exposing an application through a Kubernetes Service.
- Collecting HTTP probe metrics with Prometheus and Blackbox Exporter.
- Creating Grafana dashboards and defining a Prometheus alert rule.
- Separating implemented components from future automation work.

## Author

**Samir Maji**

DevOps and Cloud Engineering Portfolio Project

Repository: https://github.com/samirmaji-tech/container-security-scanning-pipeline
