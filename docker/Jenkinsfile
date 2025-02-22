pipeline {
    agent any
    
    environment {
        AWS_REGION = 'eu-west-2'
        ECR_REPOSITORY = '571600871041.dkr.ecr.eu-west-2.amazonaws.com'
        HMS_DEV_EC2_INSTANCE = 'ec2-13-40-17-170.eu-west-2.compute.amazonaws.com'
        SSH_CREDENTIALS = 'ec2-ssh-key'
        AWS_ACCESS_KEY = credentials('aws-access-key-id')
        AWS_SECRET_KEY = credentials('aws-secret-key')
        SLACK_CHANNEL = '#deployments'
        HMS_DEV_DOMAIN_NAME = 'lafiahms.lafialink-dev.com'
        HMS_DEV_SSL_EMAIL = 'services@seerglobalsolutions.com'
    }
    
    stages {
        stage('Checkout') {
            steps {
                // Checkout your repository which contains the docker-compose.yml
                checkout scm
            }
        }

        stage('AWS Authentication') {
            steps {
                sh '''
                    aws configure set aws_access_key_id ${AWS_ACCESS_KEY}
                    aws configure set aws_secret_access_key ${AWS_SECRET_KEY}
                    aws configure set region ${AWS_REGION}
                    aws configure set output json
                '''
            }
        }
        
        stage('ECR Login') {
            steps {
                sh '''
                    aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REPOSITORY}
                '''
            }
        }

        stage('Install Dependencies on EC2') {
            steps {
                sshagent([SSH_CREDENTIALS]) {
                    sh '''
                        ssh -o StrictHostKeyChecking=no ec2-user@${HMS_DEV_EC2_INSTANCE} "
                            if ! command -v docker &> /dev/null; then
                                sudo yum update -y && \
                                sudo yum install -y docker && \
                                sudo service docker start && \
                                sudo usermod -a -G docker ec2-user
                            fi && \
                            if ! command -v docker-compose &> /dev/null; then
                                sudo curl -L 'https://github.com/docker/compose/releases/latest/download/docker-compose-Linux-x86_64' -o /usr/local/bin/docker-compose && \
                                sudo chmod +x /usr/local/bin/docker-compose
                            fi && \
                            mkdir -p ~/openmrs-deployment"
                    '''
                }
            }
        }

        stage('Deploy to EC2') {
            steps {
                withCredentials([
                    usernamePassword(credentialsId: 'hms-dev-db-credentials', usernameVariable: 'HMS_DEV_DB_USER', passwordVariable: 'HMS_DEV_DB_PASSWORD'),
                    string(credentialsId: 'hms-dev-db-host', variable: 'HMS_DEV_DB_HOST'),
                    string(credentialsId: 'hms-dev-db-name', variable: 'HMS_DEV_DB_NAME')
                ]) {
                    sshagent([SSH_CREDENTIALS]) {
                        sh '''
                            # Copy deployment files
                            scp -o StrictHostKeyChecking=no docker/docker-compose.yml ec2-user@${HMS_DEV_EC2_INSTANCE}:~/openmrs-deployment/
                            
                            # Deploy with credentials and enhanced error handling
                            ssh -o StrictHostKeyChecking=no ec2-user@${HMS_DEV_EC2_INSTANCE} "
                                set -e
                                export AWS_ACCESS_KEY_ID='${AWS_ACCESS_KEY}'
                                export AWS_SECRET_ACCESS_KEY='${AWS_SECRET_KEY}'
                                export AWS_DEFAULT_REGION='${AWS_REGION}'
                                
                                # Export database credentials for docker-compose
                                export HMS_DEV_DB_HOST='${HMS_DEV_DB_HOST}'
                                export HMS_DEV_DB_NAME='${HMS_DEV_DB_NAME}'
                                export HMS_DEV_DB_USER='${HMS_DEV_DB_USER}'
                                export HMS_DEV_DB_PASSWORD='${HMS_DEV_DB_PASSWORD}'
                                
                                cd ~/openmrs-deployment
                                
                                echo 'Logging into ECR...'
                                aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REPOSITORY}
                                
                                echo 'Stopping existing containers...'
                                docker-compose down --remove-orphans || true
                                
                                echo 'Pulling new images...'
                                docker-compose pull --quiet
                                
                                echo 'Starting containers...'
                                docker-compose up -d
                                
                                echo 'Waiting for services to initialize...'
                                sleep 30
                                
                                echo 'Checking container logs...'
                                docker-compose logs --tail=100 backend
                                
                                echo 'Checking container status...'
                                if ! docker-compose ps | grep -q 'Up'; then
                                    echo 'Containers failed to start properly'
                                    docker-compose ps
                                    exit 1
                                fi
                            "
                        '''
                    }
                }
            }
        }

        stage('Health Check') {
            steps {
                sshagent([SSH_CREDENTIALS]) {
                    script {
                        def maxRetries = 10
                        def retryInterval = 30
                        def success = false
                        
                        for (int i = 0; i < maxRetries && !success; i++) {
                            try {
                                sh """
                                    ssh -o StrictHostKeyChecking=no ec2-user@${HMS_DEV_EC2_INSTANCE} '
                                        cd ~/openmrs-deployment
                                        
                                        # Check if all required services are running
                                        running_containers=\$(docker-compose ps --services --filter "status=running" | wc -l)
                                        echo "Running containers: \$running_containers"
                                        
                                        if [ \$running_containers -ge 3 ]; then
                                            echo "All containers are running"
                                            exit 0
                                        else
                                            echo "Not all services are running"
                                            docker-compose ps
                                            docker-compose logs --tail=50
                                            exit 1
                                        fi
                                    '
                                """
                                success = true
                                echo "All services are healthy!"
                            } catch (Exception e) {
                                if (i < maxRetries - 1) {
                                    echo "Attempt ${i + 1} failed, waiting ${retryInterval} seconds before retry..."
                                    sleep retryInterval
                                } else {
                                    error "Health check failed after ${maxRetries} attempts"
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    post {
        success {
            script {
                try {
                    slackSend(
                        teamDomain: 'lafialinkdevteam',
                        channel: SLACK_CHANNEL,
                        tokenCredentialId: 'slack-bot-user-oath-token',
                        color: 'good',
                        message: "*Success!* OpenMRS deployment `${env.JOB_NAME}` #${env.BUILD_NUMBER}\n*Duration:* ${currentBuild.durationString}"
                    )
                } catch (Exception e) {
                    echo "Failed to send Slack notification: ${e.message}"
                }
            }
        }
        failure {
            script {
                try {
                    slackSend(
                        teamDomain: 'lafialinkdevteam',
                        channel: SLACK_CHANNEL,
                        tokenCredentialId: 'slack-bot-user-oath-token',
                        color: 'danger',
                        message: "*Failed!* OpenMRS deployment `${env.JOB_NAME}` #${env.BUILD_NUMBER}\n*Duration:* ${currentBuild.durationString}"
                    )
                } catch (Exception e) {
                    echo "Failed to send Slack notification: ${e.message}"
                }
            }
        }
    }
}