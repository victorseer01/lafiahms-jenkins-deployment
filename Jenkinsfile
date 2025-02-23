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

    parameters {
        booleanParam(name: 'SETUP_SSL', defaultValue: false, description: 'Setup Let\'s Encrypt SSL?')
    }
    
    stages {
        stage('Setup SSL') {
            when {
                expression { params.SETUP_SSL }
            }
            steps {
                sshagent([SSH_CREDENTIALS]) {
                    sh '''
                        ssh -o StrictHostKeyChecking=no ec2-user@${HMS_DEV_EC2_INSTANCE} "
                            # Stop containers to free port 80
                            cd ~/openmrs-deployment
                            docker-compose down || true

                            # Install certbot if not present
                            if ! command -v certbot &> /dev/null; then
                                sudo yum install -y certbot
                            fi

                            # Get certificate
                            sudo certbot certonly --standalone \
                                --non-interactive \
                                --agree-tos \
                                --email ${HMS_DEV_SSL_EMAIL} \
                                --domain ${HMS_DEV_DOMAIN_NAME}

                            # Copy certificates
                            sudo cp /etc/letsencrypt/live/${HMS_DEV_DOMAIN_NAME}/fullchain.pem ~/openmrs-deployment/config/ssl/cert.pem
                            sudo cp /etc/letsencrypt/live/${HMS_DEV_DOMAIN_NAME}/privkey.pem ~/openmrs-deployment/config/ssl/privkey.pem
                            sudo chown -R ec2-user:ec2-user ~/openmrs-deployment/config/ssl/
                        "
                    '''
                }
            }
        }

        stage('Deploy') {
            steps {
                withCredentials([
                    usernamePassword(credentialsId: 'hms-dev-db-credentials', usernameVariable: 'HMS_DEV_DB_USER', passwordVariable: 'HMS_DEV_DB_PASSWORD'),
                    string(credentialsId: 'hms-dev-db-host', variable: 'HMS_DEV_DB_HOST'),
                    string(credentialsId: 'hms-dev-db-name', variable: 'HMS_DEV_DB_NAME')
                ]) {
                    sshagent([SSH_CREDENTIALS]) {
                        sh '''
                            # Create directories
                            ssh -o StrictHostKeyChecking=no ec2-user@${HMS_DEV_EC2_INSTANCE} "
                                mkdir -p ~/openmrs-deployment/config/nginx
                                mkdir -p ~/openmrs-deployment/config/ssl
                            "
                            
                            # Copy files
                            scp -o StrictHostKeyChecking=no docker/docker-compose.yml ec2-user@${HMS_DEV_EC2_INSTANCE}:~/openmrs-deployment/
                            scp -o StrictHostKeyChecking=no config/nginx/gateway.conf ec2-user@${HMS_DEV_EC2_INSTANCE}:~/openmrs-deployment/config/nginx/
                            
                            # Self-signed cert fallback
                            ssh -o StrictHostKeyChecking=no ec2-user@${HMS_DEV_EC2_INSTANCE} "
                                cd ~/openmrs-deployment
                                if [ ! -f config/ssl/cert.pem ]; then
                                    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
                                        -keyout config/ssl/privkey.pem \
                                        -out config/ssl/cert.pem \
                                        -subj '/CN=${HMS_DEV_DOMAIN_NAME}'
                                fi

                                # Deploy application
                                export AWS_ACCESS_KEY_ID='${AWS_ACCESS_KEY}'
                                export AWS_SECRET_ACCESS_KEY='${AWS_SECRET_KEY}'
                                export AWS_DEFAULT_REGION='${AWS_REGION}'
                                export HMS_DEV_DB_HOST='${HMS_DEV_DB_HOST}'
                                export HMS_DEV_DB_NAME='${HMS_DEV_DB_NAME}'
                                export HMS_DEV_DB_USER='${HMS_DEV_DB_USER}'
                                export HMS_DEV_DB_PASSWORD='${HMS_DEV_DB_PASSWORD}'
                                
                                aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REPOSITORY}
                                docker-compose pull --quiet
                                docker-compose up -d
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