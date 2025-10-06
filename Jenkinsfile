pipeline {
  agent {
    docker {
      image 'node:16-alpine'
      args  '-u root:root -v /var/run/docker.sock:/var/run/docker.sock'
    }
  }

  options {
    ansiColor('xterm')
    timestamps()
    buildDiscarder(logRotator(numToKeepStr: '20', artifactDaysToKeepStr: '7'))
  }

  stages {
    stage('Prep tools') {
      steps {
        sh '''
          if ! command -v docker >/dev/null 2>&1; then
            apk update && apk add --no-cache docker-cli
          fi
          node -v && npm -v && docker --version
          npm install -g snyk@latest
          snyk --version
        '''
      }
    }

    stage('Install deps') {
      steps { sh 'npm install --save' }
    }

    stage('Unit tests') {
      steps { sh 'npm test' }
    }

    // --- Security: dependencies (fail on High/Critical) ---
    stage('Security: Snyk (deps)') {
      steps {
        withCredentials([string(credentialsId: 'snyk-token', variable: 'SNYK_TOKEN_FALLBACK')]) {
          sh '''
            [ -f .env ] && . ./.env || true
            : "${SNYK_TOKEN:=$SNYK_TOKEN_FALLBACK}"  # prefer .env, else Jenkins cred
            test -n "$SNYK_TOKEN" || { echo "SNYK_TOKEN missing"; exit 2; }
            # no interactive auth; token in env is enough
            set -o pipefail
            snyk test --severity-threshold=high | tee snyk-deps.txt
          '''
        }
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

    // --- Security: container image (fail on High/Critical) ---
    stage('Security: Snyk (container)') {
      steps {
        withCredentials([string(credentialsId: 'snyk-token', variable: 'SNYK_TOKEN_FALLBACK')]) {
          sh '''
            [ -f .env ] && . ./.env || true
            : "${SNYK_TOKEN:=$SNYK_TOKEN_FALLBACK}"
            test -n "$SNYK_TOKEN" || { echo "SNYK_TOKEN missing"; exit 2; }
            set -o pipefail
            snyk container test $DOCKERHUB_USER/$IMAGE:$BUILD_NUMBER --file=Dockerfile --severity-threshold=high | tee snyk-image.txt
          '''
        }
      }
      post {
        failure { echo 'Security scan failed due to High/Critical vulnerabilities.' }
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
