pipeline {
    agent any
    environment {
        AWS_REGION = 'us-east-1'
        REPOSITORY_URI = '139156132664.dkr.ecr.us-east-1.amazonaws.com/my-app-repo'

    }

    stages {
        stage('Checkout Code') {
            steps {
                git branch: 'main',
                credentialsId: 'GITHUB_LOGIN',
                url: 'https://github.com/franklyniyala/my-app.git'
            }
        }

        stage('SonarQube Analysis') {
            steps {
                withCredentials([string(credentialsId: 'SONAR_TOKEN', variable: 'SONAR_TOKEN')]){
                    sh '''
                    docker run --rm \
                    -e SONAR_TOKEN=$SONAR_TOKEN \
                    -v $(pwd):/usr/src \
                    sonarsource/sonar-scanner-cli \
                    -Dsonar.projectKey=frank-org_my-app \
                    -Dsonar.organization=frank-org \
                    -Dsonar.sources=. \
                    -Dsonar.exclusions=node_modules/**,public/** \
                    -Dsonar.tests=. \
                    -Dsonar.test.inclusions=test.js \
                    -Dsonar.javascript.lcov.reportPaths=coverage/lcov.info \
                    -Dsonar.host.url=https://sonarcloud.io \
                    '''

                }
            }
        }

        stage ('Login to ECR') {
            steps {
                withCredentials([aws(credentialsId: 'AWS_CRED_LOGIN', accessKeyVariable: 'AWS_ACCESS_KEY_ID', secretKeyVariable: 'AWS_SECRET_ACCESS_KEY')]) {
                    sh '''
                    aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $REPOSITORY_URI
                    '''
                }
            }
        }

        stage('Build Image') {
            steps {
                sh '''
                docker build -t my-app:latest .
                docker tag my-app:latest $REPOSITORY_URI:latest
                '''
            }
        }

        stage('Push Image to ECR') {
            steps {
                sh '''
                docker push $REPOSITORY_URI:latest
                '''
            }
        }
    }

    post {
        success {
            echo ' ✅ SonarQube Analysis Successful!'
            echo ' ✅ Docker Image Built and Pushed to ECR! 🚀'
            echo 'Pushed Image: $REPOSITORY_URI:latest'
        }

        failure {
            echo ' ❌ Build failed. Check logs for details.'
        }
    }
}