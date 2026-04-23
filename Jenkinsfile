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
        withCredentials([string(credentialsId: 'SONAR_TOKEN', variable: 'SONAR_TOKEN')]) {
            sh '''
                docker run --rm \
                -e SONAR_TOKEN=$SONAR_TOKEN \
                -v $(pwd):/usr/src \
                sonarsource/sonar-scanner-cli \
                -Dsonar.projectKey=frank-org_my-app \
                -Dsonar.organization=frank-org \
                -Dsonar.sources=. \
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

        stage('Deploy to Kubernetes') {
    steps {
        withCredentials([
            file(credentialsId: 'KUBE_CONFIG_DEVOPS', variable: 'KUBECONFIG'),
            string(credentialsId: 'AWS_ACCESS_KEY_ID', variable: 'AWS_ACCESS_KEY_ID'),
            string(credentialsId: 'AWS_SECRET_ACCESS_KEY', variable: 'AWS_SECRET_ACCESS_KEY')
        ]) {
            sh """
                export KUBECONFIG=$KUBECONFIG
                export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
                export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY
                export AWS_REGION=us-east-1

                echo "Installing Prometheus monitor..."
                helm repo add prometheus-community https://prometheus-community.github.io/helm-charts || true
                helm repo update
                helm upgrade --install prometheus prometheus-community/kube-prometheus-stack --namespace monitoring --create-namespace

                echo "Updating image tag in deployment.yaml..."
                sed -i 's|image:ERC_URI:latest|${REPOSITORY_URI}:latest|g' K8s/deployment.yaml

                echo "Applying Kubernetes Manifests..."
                kubectl apply -f K8s/

                echo "Verifying Rollout..."
                kubectl rollout status deployment/my-app
            """
        }
    }
}
    }

    post {
        success {
            echo ' ✅ SonarQube Analysis Successful!'
            echo ' ✅ Docker Image Built and Pushed to ECR! 🚀'
            echo ' ✅ Kubernetes Deployment Successful! 🎉'
            echo "Pushed Image: $REPOSITORY_URI:latest"
        }

        failure {
            echo ' ❌ Build failed. Check logs for details.'
        }
    }
}