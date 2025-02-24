#!/bin/bash

# SSL Setup script
DOMAIN="lafiahms.lafialink-dev.com"
EMAIL="services@seerglobalsolutions.com"

# Stop any running containers that might use port 80
cd ~/openmrs-deployment
docker-compose down || true

# Install certbot if not already installed
if ! command -v certbot &> /dev/null; then
    sudo yum install -y certbot
fi

# Request certificate
sudo certbot certonly --standalone \
    --non-interactive \
    --agree-tos \
    --email $EMAIL \
    --domain $DOMAIN

# Create directories if they don't exist
mkdir -p ~/openmrs-deployment/config/ssl

# Copy certificates
sudo cp /etc/letsencrypt/live/$DOMAIN/fullchain.pem ~/openmrs-deployment/config/ssl/cert.pem
sudo cp /etc/letsencrypt/live/$DOMAIN/privkey.pem ~/openmrs-deployment/config/ssl/privkey.pem
sudo chown -R ec2-user:ec2-user ~/openmrs-deployment/config/ssl/

# Set up auto-renewal with correct paths
echo "0 0,12 * * * root certbot renew --quiet --post-hook 'cp /etc/letsencrypt/live/$DOMAIN/fullchain.pem ~/openmrs-deployment/config/ssl/cert.pem && cp /etc/letsencrypt/live/$DOMAIN/privkey.pem ~/openmrs-deployment/config/ssl/privkey.pem && chown -R ec2-user:ec2-user ~/openmrs-deployment/config/ssl/'" | sudo tee -a /etc/crontab > /dev/null

echo "SSL certificate setup complete!"