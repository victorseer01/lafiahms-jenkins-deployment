pipeline {
    agent any

     triggers {
        githubPush() 
    }
    
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
        stage('Deploy to EC2') {
            steps {
                withCredentials([
                    usernamePassword(credentialsId: 'hms-dev-db-credentials', usernameVariable: 'HMS_DEV_DB_USER', passwordVariable: 'HMS_DEV_DB_PASSWORD'),
                    string(credentialsId: 'hms-dev-db-host', variable: 'HMS_DEV_DB_HOST'),
                    string(credentialsId: 'hms-dev-db-name', variable: 'HMS_DEV_DB_NAME')
                ]) {
                    sshagent([SSH_CREDENTIALS]) {
                        sh '''
                            # Create deployment directories
                            ssh -o StrictHostKeyChecking=no ec2-user@${HMS_DEV_EC2_INSTANCE} "
                                mkdir -p ~/openmrs-deployment/config/nginx
                                mkdir -p ~/openmrs-deployment/config/ssl
                            "
                            
                            # Copy deployment files
                            scp -o StrictHostKeyChecking=no docker/docker-compose.yml ec2-user@${HMS_DEV_EC2_INSTANCE}:~/openmrs-deployment/
                            scp -o StrictHostKeyChecking=no config/nginx/gateway.conf ec2-user@${HMS_DEV_EC2_INSTANCE}:~/openmrs-deployment/config/nginx/
                            
                            # SSL Certificates Management (check if certificates exist)
                            ssh -o StrictHostKeyChecking=no ec2-user@${HMS_DEV_EC2_INSTANCE} "
                                if [ ! -f ~/openmrs-deployment/config/ssl/cert.pem ] || [ ! -f ~/openmrs-deployment/config/ssl/privkey.pem ]; then
                                    echo 'SSL certificates not found. Checking Let's Encrypt certificates...'
                                    
                                    if [ -f /etc/letsencrypt/live/${HMS_DEV_DOMAIN_NAME}/fullchain.pem ] && [ -f /etc/letsencrypt/live/${HMS_DEV_DOMAIN_NAME}/privkey.pem ]; then
                                        echo 'Using existing Let's Encrypt certificates'
                                        sudo cp /etc/letsencrypt/live/${HMS_DEV_DOMAIN_NAME}/fullchain.pem ~/openmrs-deployment/config/ssl/cert.pem
                                        sudo cp /etc/letsencrypt/live/${HMS_DEV_DOMAIN_NAME}/privkey.pem ~/openmrs-deployment/config/ssl/privkey.pem
                                        sudo chown ec2-user:ec2-user ~/openmrs-deployment/config/ssl/*.pem
                                    else
                                        echo 'Generating self-signed certificates'
                                        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \\
                                        -keyout ~/openmrs-deployment/config/ssl/privkey.pem \\
                                        -out ~/openmrs-deployment/config/ssl/cert.pem \\
                                        -subj \"/CN=${HMS_DEV_DOMAIN_NAME}\"
                                    fi
                                else
                                    echo 'SSL certificates already exist, skipping certificate generation'
                                fi
                            "
                            
                            # Deploy with credentials and enhanced error handling
                            ssh -o StrictHostKeyChecking=no ec2-user@${HMS_DEV_EC2_INSTANCE} "
                                set -e
                                export AWS_ACCESS_KEY_ID='${AWS_ACCESS_KEY}'
                                export AWS_SECRET_ACCESS_KEY='${AWS_SECRET_KEY}'
                                export AWS_DEFAULT_REGION='${AWS_REGION}'
                                export HMS_DEV_DOMAIN_NAME='${HMS_DEV_DOMAIN_NAME}'
                                export HMS_DEV_SSL_EMAIL='${HMS_DEV_SSL_EMAIL}'
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
                                sleep 60
                                
                                echo 'Checking container logs...'
                                docker-compose logs
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
                                        
                                        # Check container status
                                        running_containers=\$(docker-compose ps --services --filter "status=running" | wc -l)
                                        echo "Running containers: \$running_containers"
                                        
                                        if [ \$running_containers -ge 5 ]; then
                                            echo "All containers are running"
                                            exit 0
                                        else
                                            echo "Not all containers are running"
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
                        message: "*Success!* OpenMRS deployment `${env.JOB_NAME} running on ${HMS_DEV_DOMAIN_NAME}` #${env.BUILD_NUMBER}\n*Duration:* ${currentBuild.durationString}"
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