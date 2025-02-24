#!/bin/bash
set -e

# Validate inputs
if [ -z "$DOMAIN" ] || [ -z "$EMAIL" ]; then
    echo "DOMAIN and EMAIL must be set"
    exit 1
fi

# Stop running containers
cd ~/openmrs-deployment
docker-compose down || true

# Install certbot
if ! command -v certbot &> /dev/null; then
    sudo yum install -y certbot
fi

# Get certificate
sudo certbot certonly --standalone \
    --non-interactive \
    --agree-tos \
    --email $EMAIL \
    --domain $DOMAIN

# Verify certificate
if [ ! -d "/etc/letsencrypt/live/$DOMAIN" ]; then
    echo "Failed to obtain SSL certificates"
    exit 1
fi

# Setup directories and copy certificates
mkdir -p ~/openmrs-deployment/config/ssl
sudo cp /etc/letsencrypt/live/$DOMAIN/fullchain.pem ~/openmrs-deployment/config/ssl/cert.pem
sudo cp /etc/letsencrypt/live/$DOMAIN/privkey.pem ~/openmrs-deployment/config/ssl/privkey.pem
sudo chown -R ec2-user:ec2-user ~/openmrs-deployment/config/ssl/

# Setup auto-renewal
echo "0 0,12 * * * root certbot renew --quiet --post-hook 'cp /etc/letsencrypt/live/$DOMAIN/fullchain.pem ~/openmrs-deployment/config/ssl/cert.pem && cp /etc/letsencrypt/live/$DOMAIN/privkey.pem ~/openmrs-deployment/config/ssl/privkey.pem && chown -R ec2-user:ec2-user ~/openmrs-deployment/config/ssl/'" | sudo tee -a /etc/crontab > /dev/null

echo "SSL certificate setup complete"