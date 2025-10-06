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

    // 0) Ensure .env exists (create it from Jenkins creds if missing)
    stage('Prepare .env') {
      steps {
        withCredentials([
          usernamePassword(credentialsId: 'dockerhub', usernameVariable: 'DH_USER', passwordVariable: 'DH_PASS'),
          string(credentialsId: 'snyk-token', variable: 'SNYK_PAT')
        ]) {
          sh '''
            if [ ! -f .env ]; then
              cat > .env <<EOF
              DOCKERHUB_USER=${DH_USER}
              DOCKERHUB_PASS=${DH_PASS}
              IMAGE=eb-node-sample-assignment02-task03
              SNYK_TOKEN=${SNYK_PAT}
              EOF
              echo "[Prepare .env] Created .env from Jenkins credentials"
            else
              echo "[Prepare .env] Found existing .env"
            fi
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
      steps { sh 'npm install --save' }
    }

    stage('Unit tests') {
      steps { sh 'npm test' }
    }

    // Build image — with safe fallbacks if .env is missing/empty
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

    // --- Security: Snyk (deps) ---
    stage('Security: Snyk (deps)') {
      steps {
        withCredentials([string(credentialsId: 'snyk-token', variable: 'SNYK_TOKEN_FALLBACK')]) {
          sh '''
            [ -f .env ] && . ./.env || true
            SNYK_TOKEN="${SNYK_TOKEN:-$SNYK_TOKEN_FALLBACK}"
            SNYK_TOKEN="$(printf '%s' "$SNYK_TOKEN" | tr -d '\\r\\n')"
            export SNYK_TOKEN
            snyk auth "$SNYK_TOKEN" >/dev/null 2>&1 || true
            set -o pipefail
            snyk test --severity-threshold=high | tee snyk-deps.txt
          '''
        }
      }
    }

    // --- Security: Snyk (container) ---
    stage('Security: Snyk (container)') {
      steps {
        withCredentials([string(credentialsId: 'snyk-token', variable: 'SNYK_TOKEN_FALLBACK')]) {
          sh '''
            [ -f .env ] && . ./.env || true
            SNYK_TOKEN="${SNYK_TOKEN:-$SNYK_TOKEN_FALLBACK}"
            SNYK_TOKEN="$(printf '%s' "$SNYK_TOKEN" | tr -d '\\r\\n')"
            export SNYK_TOKEN
            snyk auth "$SNYK_TOKEN" >/dev/null 2>&1 || true
            DOCKERHUB_USER="${DOCKERHUB_USER:-gamerssassin}"
            IMAGE="${IMAGE:-eb-node-sample-assignment02-task03}"
            set -o pipefail
            snyk container test "$DOCKERHUB_USER/$IMAGE:$BUILD_NUMBER" --file=Dockerfile --severity-threshold=high | tee snyk-image.txt
          '''
        }
      }
      post { failure { echo 'Security scan failed due to High/Critical vulnerabilities.' } }
    }

    // Push image — with safe fallbacks and credential backup
    stage('Push image') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'dockerhub', usernameVariable: 'DH_USER', passwordVariable: 'DH_PASS')]) {
          sh '''
            [ -f .env ] && . ./.env || true
            DOCKERHUB_USER="${DOCKERHUB_USER:-$DH_USER}"
            DOCKERHUB_PASS="${DOCKERHUB_PASS:-$DH_PASS}"
            IMAGE="${IMAGE:-eb-node-sample-assignment02-task03}"
            TAG="$DOCKERHUB_USER/$IMAGE:$BUILD_NUMBER"
            printf '%s' "$DOCKERHUB_PASS" | docker login -u "$DOCKERHUB_USER" --password-stdin
            docker push "$TAG"
            docker tag  "$TAG" "$DOCKERHUB_USER/$IMAGE:latest"
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
