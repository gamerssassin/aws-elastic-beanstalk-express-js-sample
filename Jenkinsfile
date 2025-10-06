pipeline {
  agent {
    docker {
      image 'node:16'
      args  '-u root:root -v /var/run/docker.sock:/var/run/docker.sock'
    }
  }

  options {
    timestamps()
    ansiColor('xterm')
    buildDiscarder(
      logRotator(numToKeepStr: '20', artifactDaysToKeepStr: '7')
    )
  }

  stages {
    stage('Prep tools') {
      steps {
        sh '''
          apt-get update && apt-get install -y docker.io >/dev/null 2>&1 || true
          npm install -g snyk@latest
          node -v && npm -v && snyk --version && docker --version
        '''
      }
    }

    stage('Install deps') {
      steps {
        sh 'npm install --save'
      }
    }

    stage('Unit tests') {
      steps {
        sh 'npm test'
      }
    }

    stage('Security: Snyk (deps)') {
      steps {
        sh '''
          [ -f .env ] && . ./.env || true
          snyk auth "$SNYK_TOKEN"
          set -o pipefail
          snyk test --severity-threshold=high | tee snyk-deps.txt
        '''
      }
    }

    stage('Build image') {
      steps {
        sh '''
          [ -f .env ] && . ./.env || true
          docker build -t $DOCKERHUB_USER/$IMAGE:$BUILD_NUMBER .
        '''
      }
    }

    stage('Security: Snyk (container)') {
      steps {
        sh '''
          [ -f .env ] && . ./.env || true
          snyk auth "$SNYK_TOKEN"
          set -o pipefail
          snyk container test $DOCKERHUB_USER/$IMAGE:$BUILD_NUMBER --file=Dockerfile --severity-threshold=high | tee snyk-image.txt
        '''
      }
      post {
        failure {
          echo 'Security scan failed due to High/Critical vulnerabilities.'
        }
      }
    }

    stage('Push image') {
      steps {
        sh '''
          [ -f .env ] && . ./.env || true
          printf '%s' "$DOCKERHUB_PASS" | docker login -u "$DOCKERHUB_USER" --password-stdin
          docker push $DOCKERHUB_USER/$IMAGE:$BUILD_NUMBER
          docker tag  $DOCKERHUB_USER/$IMAGE:$BUILD_NUMBER $DOCKERHUB_USER/$IMAGE:latest
          docker push $DOCKERHUB_USER/$IMAGE:latest
        '''
      }
    }
  }

  post {
    always {
      archiveArtifacts artifacts: 'snyk-*.txt, Dockerfile, package*.json, Jenkinsfile', fingerprint: true
    }
  }
}
