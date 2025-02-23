#!/bin/bash
# Run this script once to set up Let's Encrypt certificates
# Save this as scripts/setup-ssl.sh in your repository

DOMAIN="lafiahms.lafialink-dev.com"
EMAIL="services@seerglobalsolutions.com"

# Stop any running containers that might use port 80
docker-compose down || true

# Install certbot if not already installed
if ! command -v certbot &> /dev/null; then
    sudo amazon-linux-extras install epel -y
    sudo yum install certbot -y
fi

# Request certificate
sudo certbot certonly --standalone \
  --non-interactive \
  --agree-tos \
  --email $EMAIL \
  --domain $DOMAIN

# Create directories
mkdir -p ~/openmrs-deployment/config/ssl

# Copy certificates
sudo cp /etc/letsencrypt/live/$DOMAIN/fullchain.pem ~/openmrs-deployment/config/ssl/cert.pem
sudo cp /etc/letsencrypt/live/$DOMAIN/privkey.pem ~/openmrs-deployment/config/ssl/privkey.pem
sudo chown ec2-user:ec2-user ~/openmrs-deployment/config/ssl/*.pem

# Set up auto-renewal
echo "0 0,12 * * * root certbot renew --quiet --post-hook 'cp /etc/letsencrypt/live/$DOMAIN/fullchain.pem ~/openmrs-deployment/config/ssl/cert.pem && cp /etc/letsencrypt/live/$DOMAIN/privkey.pem ~/openmrs-deployment/config/ssl/privkey.pem && chown ec2-user:ec2-user ~/openmrs-deployment/config/ssl/*.pem'" | sudo tee -a /etc/crontab > /dev/null

echo "SSL certificate setup complete!"