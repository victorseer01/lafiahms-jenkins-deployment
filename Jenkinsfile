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
    }
    
    stages {
        stage('Deploy') {
            steps {
                timeout(time: 10, unit: 'MINUTES') {
                    withCredentials([
                        usernamePassword(credentialsId: 'hms-dev-db-credentials', usernameVariable: 'HMS_DEV_DB_USER', passwordVariable: 'HMS_DEV_DB_PASSWORD'),
                        string(credentialsId: 'hms-dev-db-host', variable: 'HMS_DEV_DB_HOST'),
                        string(credentialsId: 'hms-dev-db-name', variable: 'HMS_DEV_DB_NAME')
                    ]) {
                        sshagent([SSH_CREDENTIALS]) {
                            sh '''
                                # Setup directories
                                ssh -o StrictHostKeyChecking=no ec2-user@${HMS_DEV_EC2_INSTANCE} "
                                    mkdir -p ~/openmrs-deployment/config/nginx
                                    mkdir -p ~/openmrs-deployment/config/ssl
                                "
                                
                                # Copy files
                                scp -o StrictHostKeyChecking=no docker/docker-compose.yml ec2-user@${HMS_DEV_EC2_INSTANCE}:~/openmrs-deployment/
                                scp -o StrictHostKeyChecking=no config/nginx/gateway.conf ec2-user@${HMS_DEV_EC2_INSTANCE}:~/openmrs-deployment/config/nginx/
                                
                                # Deploy
                                ssh -o StrictHostKeyChecking=no ec2-user@${HMS_DEV_EC2_INSTANCE} "
                                    cd ~/openmrs-deployment
                                    
                                    # Verify SSL certificates exist
                                    if [ ! -f config/ssl/cert.pem ] || [ ! -f config/ssl/privkey.pem ]; then
                                        echo 'SSL certificates missing. Please run SSL setup pipeline first.'
                                        exit 1
                                    fi
                                    
                                    # Create environment file
                                    cat > .env << EOL
HMS_DEV_DB_HOST=${HMS_DEV_DB_HOST}
HMS_DEV_DB_NAME=${HMS_DEV_DB_NAME}
HMS_DEV_DB_USER=${HMS_DEV_DB_USER}
HMS_DEV_DB_PASSWORD=${HMS_DEV_DB_PASSWORD}
CORS_ALLOWED_ORIGINS=*
EOL
                                    
                                    # AWS login
                                    aws configure set aws_access_key_id ${AWS_ACCESS_KEY}
                                    aws configure set aws_secret_access_key ${AWS_SECRET_KEY}
                                    aws configure set region ${AWS_REGION}
                                    aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REPOSITORY}
                                    
                                    # Deploy services
                                    docker-compose down --remove-orphans
                                    docker-compose pull --quiet
                                    docker-compose up -d
                                    
                                    # Wait and check status
                                    echo 'Waiting for services to initialize...'
                                    sleep 45
                                    
                                    if ! docker-compose ps | grep -q "Up"; then
                                        echo "Deployment failed. Container logs:"
                                        docker-compose logs
                                        exit 1
                                    fi
                                "
                            '''
                        }
                    }
                }
            }
        }
    }
    
    post {
        success {
            slackSend(channel: SLACK_CHANNEL, color: 'good', 
                message: "*Success!* OpenMRS deployment`${env.JOB_NAME}` #${env.BUILD_NUMBER}")
        }
        failure {
            slackSend(channel: SLACK_CHANNEL, color: 'danger', 
                message: "*Failed!* OpenMRS deployment `${env.JOB_NAME}` #${env.BUILD_NUMBER}")
        }
    }
}