#!/usr/bin/env bash
set -euo pipefail

########################################
# CONFIG – EDIT THESE BEFORE RUN
########################################

PROJECT_ID="kyc-aml-automation"
ZONE="us-central1-a"               # free-tier region
VM_NAME="kyc-onboarding-vm"
MACHINE_TYPE="e2-micro"           # free-tier machine
DISK_SIZE="30GB"

# tag names for firewall
TAG_SSH="kyc-ssh"
TAG_WEB="kyc-web"

# path to your SSH public key (on the machine running this script)
SSH_PUBLIC_KEY="${HOME}/.ssh/id_rsa.pub"

########################################
# 0. PRECHECKS
########################################

if ! command -v gcloud >/dev/null 2>&1; then
  echo "gcloud CLI not found. Install Google Cloud SDK first."
  exit 1
fi

if [ ! -f "$SSH_PUBLIC_KEY" ]; then
  echo "SSH public key not found at: $SSH_PUBLIC_KEY"
  echo "Create one with: ssh-keygen -t rsa -b 4096"
  exit 1
fi

echo "Using project:      ${PROJECT_ID}"
echo "Using zone:         ${ZONE}"
echo "VM name:            ${VM_NAME}"
echo "Machine type:       ${MACHINE_TYPE}"
echo "SSH public key:     ${SSH_PUBLIC_KEY}"
echo

########################################
# 1. SET PROJECT & ENABLE APIS
########################################

echo ">> Setting gcloud project..."
gcloud config set project "${PROJECT_ID}" >/dev/null

echo ">> Enabling Compute Engine API (if not already)..."
gcloud services enable compute.googleapis.com

########################################
# 2. CREATE FIREWALL RULES (22 / 80 / 443)
########################################

echo ">> Creating firewall rules (if not exist)..."

gcloud compute firewall-rules create "${TAG_SSH}-rule" \
  --network=default \
  --allow=tcp:22 \
  --target-tags="${TAG_SSH}" \
  --quiet || echo "SSH firewall rule already exists, skipping."

gcloud compute firewall-rules create "${TAG_WEB}-rule" \
  --network=default \
  --allow=tcp:80,tcp:443 \
  --target-tags="${TAG_WEB}" \
  --quiet || echo "WEB firewall rule already exists, skipping."

########################################
# 3. WRITE STARTUP SCRIPT (VM INIT)
########################################

STARTUP_FILE="$(pwd)/startup.sh"

cat > "${STARTUP_FILE}" << 'EOF'
#!/bin/bash
set -e

apt-get update -y
apt-get upgrade -y

# base tools
apt-get install -y git build-essential nginx ufw fail2ban unattended-upgrades

# docker
curl -fsSL https://get.docker.com | sh
usermod -aG docker $USER

# docker compose
curl -L "https://github.com/docker/compose/releases/download/2.29.2/docker-compose-linux-x86_64" \
  -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# app folders
mkdir -p /srv/app/{compose,logs,nginx,certs} /srv/app/.env.d
chown -R $USER:$USER /srv/app

# firewall (ufw)
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

systemctl enable nginx
systemctl start nginx
EOF

echo ">> startup.sh written to ${STARTUP_FILE}"

########################################
# 4. CREATE VM (IF NOT EXISTS)
########################################

echo ">> Checking if VM ${VM_NAME} already exists..."
if gcloud compute instances describe "${VM_NAME}" --zone "${ZONE}" >/dev/null 2>&1; then
  echo "VM ${VM_NAME} already exists. Skipping creation."
else
  echo ">> Creating VM ${VM_NAME}..."
  gcloud compute instances create "${VM_NAME}" \
    --zone="${ZONE}" \
    --machine-type="${MACHINE_TYPE}" \
    --image-family=ubuntu-2204-lts \
    --image-project=ubuntu-os-cloud \
    --boot-disk-size="${DISK_SIZE}" \
    --tags="${TAG_SSH},${TAG_WEB}" \
    --metadata-from-file startup-script="${STARTUP_FILE}"
fi

########################################
# 5. REGISTER SSH KEY WITH OS LOGIN
########################################

echo ">> Registering SSH public key with OS Login..."
gcloud compute os-login ssh-keys add --key-file="${SSH_PUBLIC_KEY}"

########################################
# 6. PRINT EXTERNAL IP + SSH CONFIG HINT
########################################

echo ">> Fetching external IP..."
EXTERNAL_IP=$(gcloud compute instances list \
  --filter="name=${VM_NAME}" \
  --format="value(EXTERNAL_IP)")

echo
echo "===================================================="
echo " VM SETUP COMPLETE"
echo "===================================================="
echo "VM Name:     ${VM_NAME}"
echo "Project:     ${PROJECT_ID}"
echo "Zone:        ${ZONE}"
echo "External IP: ${EXTERNAL_IP}"
echo
echo "Add this to your ~/.ssh/config for VS Code Remote-SSH:"
echo
cat <<EOF
Host gcp-kyc-vm
    HostName ${EXTERNAL_IP}
    User $(whoami)
    IdentityFile ${SSH_PUBLIC_KEY/%\.pub/}
EOF
echo
echo "Then in VS Code: Remote-SSH → Connect to Host → gcp-kyc-vm"
echo "On first login run:  newgrp docker  &&  docker ps"
echo "===================================================="
