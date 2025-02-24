#!/bin/bash
set -e

echo "Starting SSL setup with DOMAIN=${DOMAIN} and EMAIL=${EMAIL}"

# Validate inputs
if [ -z "${DOMAIN}" ] || [ -z "${EMAIL}" ]; then
    echo "Error: DOMAIN and EMAIL environment variables must be set"
    exit 1
fi

# Get the actual user's home directory and create needed directories
USER_HOME=/home/ec2-user
mkdir -p ${USER_HOME}/openmrs-deployment/config/ssl

echo "Stopping any running containers..."
# Use docker directly instead of docker-compose
docker ps -q | while read container_id; do
    echo "Stopping container: $container_id"
    docker stop $container_id
done

echo "Waiting for ports to be freed..."
sleep 10

echo "Requesting certificate for domain: ${DOMAIN}"

# Get certificate
certbot certonly --standalone \
    --non-interactive \
    --agree-tos \
    --email "${EMAIL}" \
    --domain "${DOMAIN}" \
    --force-renewal

# Verify certificate
if [ ! -d "/etc/letsencrypt/live/${DOMAIN}" ]; then
    echo "Failed to obtain SSL certificates."
    exit 1
fi

echo "Copying new certificates..."
cp "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem" ${USER_HOME}/openmrs-deployment/config/ssl/cert.pem
cp "/etc/letsencrypt/live/${DOMAIN}/privkey.pem" ${USER_HOME}/openmrs-deployment/config/ssl/privkey.pem
chown -R ec2-user:ec2-user ${USER_HOME}/openmrs-deployment/config/ssl/

echo "SSL certificate setup complete!"