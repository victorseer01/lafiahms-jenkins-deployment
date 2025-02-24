#!/bin/bash
set -e

echo "Starting SSL setup with DOMAIN=${DOMAIN} and EMAIL=${EMAIL}"

# Validate inputs
if [ -z "${DOMAIN}" ] || [ -z "${EMAIL}" ]; then
    echo "Error: DOMAIN and EMAIL environment variables must be set"
    exit 1
fi

echo "Backing up existing SSL certificates..."
if [ -f ~/openmrs-deployment/config/ssl/cert.pem ]; then
    cp ~/openmrs-deployment/config/ssl/cert.pem ~/openmrs-deployment/config/ssl/cert.pem.backup
    cp ~/openmrs-deployment/config/ssl/privkey.pem ~/openmrs-deployment/config/ssl/privkey.pem.backup
fi

echo "Stopping containers..."
cd ~/openmrs-deployment
docker-compose down

echo "Waiting for ports to be freed..."
sleep 10

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
    echo "Failed to obtain SSL certificates. Restoring backup if available..."
    if [ -f ~/openmrs-deployment/config/ssl/cert.pem.backup ]; then
        mv ~/openmrs-deployment/config/ssl/cert.pem.backup ~/openmrs-deployment/config/ssl/cert.pem
        mv ~/openmrs-deployment/config/ssl/privkey.pem.backup ~/openmrs-deployment/config/ssl/privkey.pem
    fi
    exit 1
fi

echo "Copying new certificates..."
sudo cp "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem" ~/openmrs-deployment/config/ssl/cert.pem
sudo cp "/etc/letsencrypt/live/${DOMAIN}/privkey.pem" ~/openmrs-deployment/config/ssl/privkey.pem
sudo chown -R ec2-user:ec2-user ~/openmrs-deployment/config/ssl/

echo "Cleaning up backups..."
rm -f ~/openmrs-deployment/config/ssl/*.backup

echo "SSL certificate setup complete! You can now restart your containers."