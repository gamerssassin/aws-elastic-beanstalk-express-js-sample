pipeline {
  agent {
    docker {
      image 'node:16'
      args  '-u root:root -v /var/run/docker.sock:/var/run/docker.sock'
    }
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
        // rubric: must use --save
        sh 'npm install --save'
      }
    }

    stage('Unit tests') {
      steps {
        sh 'npm test'
      }
    }

    // ---- Security Gate #1: App dependencies ----
    stage('Security: Snyk (deps)') {
      steps {
        sh '''
          set -a; . ./.env; set +a
          snyk auth "$SNYK_TOKEN"
          # fail build if High/Critical vulns exist
          snyk test --severity-threshold=high
        '''
      }
    }

    stage('Build image') {
      steps {
        sh 'set -a; . ./.env; set +a; docker build -t $DOCKERHUB_USER/$IMAGE:$BUILD_NUMBER .'
      }
    }

    // ---- Security: Snyk (container) MUST FAIL AND STOP IF VULNS FOUND
    stage('Security: Snyk (container)') {
        steps {
            sh '''
            set -a; . ./.env; set +a
            snyk auth "$SNYK_TOKEN"
            snyk container test $DOCKERHUB_USER/$IMAGE:$BUILD_NUMBER --file=Dockerfile --severity-threshold=high
            '''
        }
        post {
            failure {
                echo 'Security scan failed due to high or critical vulnerabilities. Stopping the pipeline.'
                error('Pipeline stopped due to security vulnerabilities.')
            }
        }
    }

    stage('Push image') {
      steps {
        // Load env vars and push to DockerHub
        sh '''
          set -a; . ./.env; set +a 
          printf '%s' "$DOCKERHUB_PASS" | docker login -u "$DOCKERHUB_USER" --password-stdin
          docker push $DOCKERHUB_USER/$IMAGE:$BUILD_NUMBER
          docker tag  $DOCKERHUB_USER/$IMAGE:$BUILD_NUMBER $DOCKERHUB_USER/$IMAGE:latest
          docker push $DOCKERHUB_USER/$IMAGE:latest
        '''
      }
    }
  }
}