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
    }
    
    stages {
        stage('Deploy') {
            steps {
                withCredentials([
                    usernamePassword(credentialsId: 'hms-dev-db-credentials', usernameVariable: 'HMS_DEV_DB_USER', passwordVariable: 'HMS_DEV_DB_PASSWORD'),
                    string(credentialsId: 'hms-dev-db-host', variable: 'HMS_DEV_DB_HOST'),
                    string(credentialsId: 'hms-dev-db-name', variable: 'HMS_DEV_DB_NAME')
                ]) {
                    sshagent([SSH_CREDENTIALS]) {
                        sh '''
                            # Setup deployment directories
                            ssh -o StrictHostKeyChecking=no ec2-user@${HMS_DEV_EC2_INSTANCE} "
                                mkdir -p ~/openmrs-deployment/config/nginx
                                mkdir -p ~/openmrs-deployment/config/ssl
                            "
                            
                            # Copy deployment files
                            scp -o StrictHostKeyChecking=no docker/docker-compose.yml ec2-user@${HMS_DEV_EC2_INSTANCE}:~/openmrs-deployment/
                            scp -o StrictHostKeyChecking=no config/nginx/gateway.conf ec2-user@${HMS_DEV_EC2_INSTANCE}:~/openmrs-deployment/config/nginx/
                            
                            # Deploy to EC2
                            ssh -o StrictHostKeyChecking=no ec2-user@${HMS_DEV_EC2_INSTANCE} "
                                cd ~/openmrs-deployment
                                
                                # Generate SSL certificate if not exists
                                if [ ! -f config/ssl/cert.pem ]; then
                                    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
                                        -keyout config/ssl/privkey.pem \
                                        -out config/ssl/cert.pem \
                                        -subj '/CN=${HMS_DEV_DOMAIN_NAME}'
                                fi

                                # Configure AWS CLI and login to ECR
                                aws configure set aws_access_key_id ${AWS_ACCESS_KEY}
                                aws configure set aws_secret_access_key ${AWS_SECRET_KEY}
                                aws configure set region ${AWS_REGION}
                                aws configure set output json
                                
                                # Login to ECR
                                aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REPOSITORY}
                                
                                # Set environment variables
                                export HMS_DEV_DB_HOST='${HMS_DEV_DB_HOST}'
                                export HMS_DEV_DB_NAME='${HMS_DEV_DB_NAME}'
                                export HMS_DEV_DB_USER='${HMS_DEV_DB_USER}'
                                export HMS_DEV_DB_PASSWORD='${HMS_DEV_DB_PASSWORD}'
                                
                                # Stop and remove existing containers
                                docker-compose down --remove-orphans || true
                                
                                # Pull latest images
                                docker-compose pull --quiet
                                
                                # Start services
                                docker-compose up -d
                                
                                # Wait for services to initialize
                                echo 'Waiting for services to initialize...'
                                sleep 30
                                
                                # Check if services are running
                                RUNNING_CONTAINERS=\$(docker-compose ps --services --filter "status=running" | wc -l)
                                if [ \$RUNNING_CONTAINERS -lt 3 ]; then
                                    echo "Not all services are running. Current status:"
                                    docker-compose ps
                                    docker-compose logs
                                    exit 1
                                fi
                                
                                echo "All services are running successfully!"
                            "
                        '''
                    }
                }
            }
        }
    }
    
    post {
        success {
            slackSend(
                channel: SLACK_CHANNEL,
                color: 'good',
                message: "*Success!* OpenMRS deployment `${env.JOB_NAME}` #${env.BUILD_NUMBER}\n*Duration:* ${currentBuild.durationString}"
            )
        }
        failure {
            slackSend(
                channel: SLACK_CHANNEL,
                color: 'danger',
                message: "*Failed!* OpenMRS deployment `${env.JOB_NAME}` #${env.BUILD_NUMBER}\n*Duration:* ${currentBuild.durationString}"
            )
        }
    }
}