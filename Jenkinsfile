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

    // Write a non-secret .env each run (sanitizes any previous file)
    stage('Prepare .env') {
      steps {
        withCredentials([
          usernamePassword(credentialsId: 'dockerhub', usernameVariable: 'DH_USER', passwordVariable: 'DH_PASS')
        ]) {
          sh '''
            set -eu
            # Only non-secrets here
            DOCKERHUB_USER_SAFE="${DH_USER:-gamerssassin}"
            IMAGE_SAFE="${IMAGE:-eb-node-sample-assignment02-task03}"
            printf "DOCKERHUB_USER=%s\nIMAGE=%s\n" \
              "$DOCKERHUB_USER_SAFE" "$IMAGE_SAFE" > .env
            echo "[Prepare .env] Wrote sanitized .env (no secrets)"
          '''
        }
      }
    }

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
      steps { sh 'npm install --save' }   // rubric requirement
    }

    stage('Unit tests') {
      steps { sh 'npm test' }
    }

    stage('Build image') {
      steps {
        sh '''
          [ -f .env ] && . ./.env || true
          DOCKERHUB_USER="${DOCKERHUB_USER:-gamerssassin}"
          IMAGE="${IMAGE:-eb-node-sample-assignment02-task03}"
          TAG="$DOCKERHUB_USER/$IMAGE:$BUILD_NUMBER"
          echo "Building image tag: $TAG"
          docker build -t "$TAG" .
        '''
      }
    }

    // ---- Security gate #1: dependencies ----
    stage('Security: Snyk (deps)') {
      steps {
        withCredentials([string(credentialsId: 'snyk-token', variable: 'SNYK_TOKEN')]) {
          sh '''
            [ -f .env ] && . ./.env || true
            # Export token for CLI (do NOT echo it)
            export SNYK_TOKEN="$(printf '%s' "$SNYK_TOKEN" | tr -d '\\r\\n')"
            # Optional: set region endpoint (non-secret). Put SNYK_API in .env if you’re on EU/AU.
            [ -n "${SNYK_API:-}" ] && export SNYK_API
            set -o pipefail
            snyk test --severity-threshold=high | tee snyk-deps.txt
          '''
        }
      }
    }

    // ---- Security gate #2: container image ----
    stage('Security: Snyk (container)') {
      steps {
        withCredentials([string(credentialsId: 'snyk-token', variable: 'SNYK_TOKEN')]) {
          sh '''
            [ -f .env ] && . ./.env || true
            export SNYK_TOKEN="$(printf '%s' "$SNYK_TOKEN" | tr -d '\\r\\n')"
            [ -n "${SNYK_API:-}" ] && export SNYK_API
            DOCKERHUB_USER="${DOCKERHUB_USER:-gamerssassin}"
            IMAGE="${IMAGE:-eb-node-sample-assignment02-task03}"
            set -o pipefail
            snyk container test "$DOCKERHUB_USER/$IMAGE:$BUILD_NUMBER" --file=Dockerfile --severity-threshold=high | tee snyk-image.txt
          '''
        }
      }
      post { failure { echo 'Security scan failed due to High/Critical vulnerabilities.' } }
    }

    stage('Push image') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'dockerhub', usernameVariable: 'DH_USER', passwordVariable: 'DH_PASS')]) {
          sh '''
            [ -f .env ] && . ./.env || true
            DOCKERHUB_USER="${DOCKERHUB_USER:-$DH_USER}"
            IMAGE="${IMAGE:-eb-node-sample-assignment02-task03}"
            TAG="$DOCKERHUB_USER/$IMAGE:$BUILD_NUMBER"
            # Login without echoing the secret
            printf '%s' "$DH_PASS" | docker login -u "$DOCKERHUB_USER" --password-stdin
            docker push "$TAG"
            docker tag "$TAG" "$DOCKERHUB_USER/$IMAGE:latest"
            docker push "$DOCKERHUB_USER/$IMAGE:latest"
          '''
        }
      }
    }
  }

  post {
    always {
      archiveArtifacts artifacts: 'snyk-*.txt, Dockerfile, package*.json, Jenkinsfile', fingerprint: true
    }
  }
}
