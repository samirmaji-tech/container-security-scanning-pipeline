pipeline {
  agent any

  environment {
    IMAGE_NAME = "devsecops-web:${BUILD_NUMBER}"
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Build Docker Image') {
      steps {
        sh 'docker build --pull -t "$IMAGE_NAME" .'
      }
    }

    stage('Trivy Vulnerability Scan') {
      steps {
        sh 'trivy image --scanners vuln --severity HIGH,CRITICAL "$IMAGE_NAME"'
      }
    }

    stage('Security Gate') {
      steps {
        sh 'trivy image --scanners vuln --severity HIGH,CRITICAL --exit-code 1 "$IMAGE_NAME"'
      }
    }
  }

  post {
    always {
      echo 'Pipeline finished. Review the Trivy console output; the security gate fails when HIGH/CRITICAL findings are present.'
    }
  }
}
