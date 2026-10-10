# 2-minute showcase notes

## Project title
Container Security Scanning Pipeline using Docker and Trivy

## Problem statement
Container images can contain vulnerable operating-system packages or application dependencies. If an image is deployed without checks, known vulnerabilities may reach an environment.

## Solution
I packaged a small web application into a Docker image and used Trivy to scan that image against its vulnerability database. The project generates a readable report and a JSON report. An example Jenkinsfile shows how image building and scanning can be automated, with a security gate that can stop a release when HIGH or CRITICAL findings are detected.

## Workflow to explain
1. Source: a sample static web page and Dockerfile.
2. Build: Docker creates a versioned image.
3. Scan: Trivy checks image packages for known vulnerabilities.
4. Report: findings are categorized by severity and saved for review.
5. Gate: in the Jenkins example, HIGH/CRITICAL findings make the stage fail so the team investigates before release.

## Demonstration order
- Show the project structure.
- Run `docker build -t devsecops-web:1.0 .`.
- Run `trivy image --scanners vuln --severity HIGH,CRITICAL devsecops-web:1.0`.
- Open the generated report.
- Explain the Jenkinsfile and the difference between a warning/report and a blocking security gate.

## Honest scope statement
The local Docker + Trivy scan is the minimum working demonstration. Jenkins automation requires a configured Jenkins agent with Docker and Trivy installed. Kubernetes, Clair and Anchore are extensions, not part of the minimum local demo unless separately configured and demonstrated.
