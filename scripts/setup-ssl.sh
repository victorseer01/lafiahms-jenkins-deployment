#!/bin/bash
set -e

echo "Starting SSL setup with DOMAIN=${DOMAIN} and EMAIL=${EMAIL}"

# Validate inputs
if [ -z "${DOMAIN}" ] || [ -z "${EMAIL}" ]; then
    echo "Error: DOMAIN and EMAIL environment variables must be set"
    exit 1
fi

# Get the actual user's home directory
USER_HOME=$(eval echo ~${SUDO_USER})

echo "Backing up existing SSL certificates..."
if [ -f ${USER_HOME}/openmrs-deployment/config/ssl/cert.pem ]; then
    cp ${USER_HOME}/openmrs-deployment/config/ssl/cert.pem ${USER_HOME}/openmrs-deployment/config/ssl/cert.pem.backup
    cp ${USER_HOME}/openmrs-deployment/config/ssl/privkey.pem ${USER_HOME}/openmrs-deployment/config/ssl/privkey.pem.backup
fi

echo "Stopping containers..."
# Run docker-compose as the original user
sudo -u ${SUDO_USER} docker compose -f ${USER_HOME}/openmrs-deployment/docker-compose.yml down

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
    echo "Failed to obtain SSL certificates. Restoring backup if available..."
    if [ -f ${USER_HOME}/openmrs-deployment/config/ssl/cert.pem.backup ]; then
        mv ${USER_HOME}/openmrs-deployment/config/ssl/cert.pem.backup ${USER_HOME}/openmrs-deployment/config/ssl/cert.pem
        mv ${USER_HOME}/openmrs-deployment/config/ssl/privkey.pem.backup ${USER_HOME}/openmrs-deployment/config/ssl/privkey.pem
    fi
    exit 1
fi

echo "Copying new certificates..."
cp "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem" ${USER_HOME}/openmrs-deployment/config/ssl/cert.pem
cp "/etc/letsencrypt/live/${DOMAIN}/privkey.pem" ${USER_HOME}/openmrs-deployment/config/ssl/privkey.pem
chown -R ${SUDO_USER}:${SUDO_USER} ${USER_HOME}/openmrs-deployment/config/ssl/

echo "Cleaning up backups..."
rm -f ${USER_HOME}/openmrs-deployment/config/ssl/*.backup

echo "SSL certificate setup complete! You can now restart your containers."