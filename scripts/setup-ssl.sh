#!/bin/bash
set -e

echo "Starting SSL setup with DOMAIN=${DOMAIN} and EMAIL=${EMAIL}"

# Validate inputs
if [ -z "${DOMAIN}" ] || [ -z "${EMAIL}" ]; then
    echo "Error: DOMAIN and EMAIL environment variables must be set"
    echo "Current values:"
    echo "DOMAIN: ${DOMAIN}"
    echo "EMAIL: ${EMAIL}"
    exit 1
fi

# Create required directories
mkdir -p ~/openmrs-deployment/config/ssl

# Stop running containers
cd ~/openmrs-deployment
docker-compose down || true

# Install certbot if not already installed
if ! command -v certbot &> /dev/null; then
    sudo yum install -y certbot
fi

echo "Requesting certificate for domain: ${DOMAIN}"

# Get certificate
sudo certbot certonly --standalone \
    --non-interactive \
    --agree-tos \
    --email "${EMAIL}" \
    --domain "${DOMAIN}"

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

# Setup auto-renewal
RENEWAL_SCRIPT="
#!/bin/bash
certbot renew --quiet
cp /etc/letsencrypt/live/${DOMAIN}/fullchain.pem ~/openmrs-deployment/config/ssl/cert.pem
cp /etc/letsencrypt/live/${DOMAIN}/privkey.pem ~/openmrs-deployment/config/ssl/privkey.pem
chown -R ec2-user:ec2-user ~/openmrs-deployment/config/ssl/
"

echo "$RENEWAL_SCRIPT" | sudo tee /etc/cron.monthly/ssl-renewal > /dev/null
sudo chmod +x /etc/cron.monthly/ssl-renewal

echo "SSL certificate setup complete!"