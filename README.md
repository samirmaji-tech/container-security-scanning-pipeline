# Container Security Scanning Pipeline

A small, demonstrable DevSecOps project inspired by project #31, **Container Security Scanning Pipeline**, in the supplied DevOps Projects guide. The guide's broader project lists Trivy, Clair, Anchore, Jenkins, Docker and Kubernetes. This starter deliberately focuses first on Docker + Trivy so it can be demonstrated locally without deploying cloud infrastructure.

## Objective

Build a container image for a sample web app, scan the image for known vulnerabilities, save a report, and optionally enforce a release gate for HIGH/CRITICAL findings in Jenkins.

## Architecture

Developer/source code → Docker build → Container image → Trivy vulnerability scan → Report → Review / security gate → Deployment only after review

## Prerequisites

- Docker Desktop installed and running
- Trivy installed
- macOS/Homebrew installation: `brew install trivy`

Check prerequisites:

```bash
docker --version
docker ps
trivy --version
```

If `docker ps` fails, open Docker Desktop and wait for it to finish starting. Do not claim the pipeline ran until the Docker daemon is working.

## Local demonstration

From this project directory:

```bash
./scripts/scan-image.sh
```

Or run each step manually:

```bash
docker build --pull -t devsecops-web:1.0 .
trivy image --scanners vuln --severity HIGH,CRITICAL devsecops-web:1.0
mkdir -p reports
trivy image --scanners vuln --severity HIGH,CRITICAL --format table --output reports/trivy-report.txt devsecops-web:1.0
trivy image --scanners vuln --format json --output reports/trivy-report.json devsecops-web:1.0
```

Optional: run the sample page in a browser:

```bash
docker run --rm -d --name devsecops-web-demo -p 8080:80 devsecops-web:1.0
```

Open `http://localhost:8080`, then stop the container:

```bash
docker stop devsecops-web-demo
```

## Jenkins integration (optional)

The included `Jenkinsfile` demonstrates checkout, image build, Trivy scan and a security gate. Use it only on a Jenkins agent where both Docker and Trivy are installed and accessible. The final gate intentionally returns a failing status if HIGH/CRITICAL vulnerabilities are found; that is a security control, not necessarily a pipeline defect. If Jenkins is not already configured, do not spend the night setting it up—demonstrate the local Docker + Trivy scan and explain Jenkins as the next automation step.

## What to show the examiner

1. Show the Dockerfile and sample `index.html`.
2. Build the image and show the image exists with `docker images`.
3. Run the Trivy scan and explain the severity columns.
4. Open `reports/trivy-report.txt` or `reports/trivy-report.json`.
5. Explain that a security gate can stop promotion when policy-defined HIGH/CRITICAL findings exist.

Do not promise a specific number of vulnerabilities. The findings depend on the actual image version and Trivy's vulnerability database at scan time. If no HIGH/CRITICAL findings appear, show the genuine result rather than fabricating findings.

## Scope and future enhancements

Implemented starter scope: Docker image build, Trivy vulnerability scan, text/JSON reporting, and an example Jenkins pipeline definition.

Possible extensions: add Clair or Anchore for comparison, run the pipeline on every Git push, publish scan reports as Jenkins artifacts, and add Kubernetes deployment only after the scanning flow is stable.
