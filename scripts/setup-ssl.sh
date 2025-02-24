#!/bin/bash
set -e

echo "Starting SSL setup with DOMAIN=${DOMAIN} and EMAIL=${EMAIL}"

# Validate inputs
if [ -z "${DOMAIN}" ] || [ -z "${EMAIL}" ]; then
    echo "Error: DOMAIN and EMAIL environment variables must be set"
    exit 1
fi

# Stop containers since we're in the correct directory
echo "Stopping running containers..."
cd ~/openmrs-deployment
docker-compose down

echo "Waiting for ports to be freed..."
sleep 10

# Verify port 80 is free
if netstat -tuln | grep ':80 '; then
    echo "Warning: Port 80 is still in use. Attempting to stop docker-proxy..."
    sudo pkill docker-proxy || true
    sleep 5
fi

echo "Requesting certificate for domain: ${DOMAIN}"

# Get certificate
sudo certbot certonly --standalone \
    --non-interactive \
    --agree-tos \
    --email "${EMAIL}" \
    --domain "${DOMAIN}" \
    --force-renewal

# Verify certificate
if [ ! -d "/etc/letsencrypt/live/${DOMAIN}" ]; then
    echo "Failed to obtain SSL certificates"
    exit 1
fi

echo "Copying certificates to openmrs-deployment directory"

# Copy certificates
sudo cp "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem" ~/openmrs-deployment/config/ssl/cert.pem
sudo cp "/etc/letsencrypt/live/${DOMAIN}/privkey.pem" ~/openmrs-deployment/config/ssl/privkey.pem
sudo chown -R ec2-user:ec2-user ~/openmrs-deployment/config/ssl/

echo "Restarting containers..."
docker-compose up -d

echo "SSL certificate setup complete!"