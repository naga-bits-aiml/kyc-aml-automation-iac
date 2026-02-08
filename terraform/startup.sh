#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

# Metadata flags to control installation
INSTALL_DOCKER=${INSTALL_DOCKER:-0}
INSTALL_TESSERACT=${INSTALL_TESSERACT:-0}
INSTALL_NGINX=${INSTALL_NGINX:-0}
INSTALL_SUPERVISOR=${INSTALL_SUPERVISOR:-0}

echo "==> Updating apt repositories"
apt-get update -y
apt-get upgrade -y

echo "==> Installing base packages"
apt-get install -y --no-install-recommends \
  ca-certificates curl wget gnupg lsb-release software-properties-common \
  python3 python3-pip python3-venv \
  git build-essential \
  curl wget

# Install Supervisor if enabled
if [ "${INSTALL_SUPERVISOR}" = "1" ] || [ "${INSTALL_SUPERVISOR}" = "true" ]; then
  echo "==> Installing Supervisor"
  apt-get install -y --no-install-recommends supervisor
fi

# Install Nginx and security tools if enabled
if [ "${INSTALL_NGINX}" = "1" ] || [ "${INSTALL_NGINX}" = "true" ]; then
  echo "==> Installing Nginx and security tools"
  apt-get install -y --no-install-recommends \
    nginx ufw fail2ban unattended-upgrades \
    apt-transport-https
fi

# Install Docker if enabled
if [ "${INSTALL_DOCKER}" = "1" ] || [ "${INSTALL_DOCKER}" = "true" ]; then
  echo "==> Installing Docker (get.docker.com script)"
  if ! command -v docker >/dev/null 2>&1; then
    curl -fsSL https://get.docker.com | sh
  fi

  echo "==> Installing Docker Compose CLI plugin"
  CLI_PLUGIN_DIR=/usr/local/lib/docker/cli-plugins
  mkdir -p "$CLI_PLUGIN_DIR"
  COMPOSE_PATH="$CLI_PLUGIN_DIR/docker-compose"
  if [ ! -x "$COMPOSE_PATH" ]; then
    curl -SL "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64" -o "$COMPOSE_PATH"
    chmod +x "$COMPOSE_PATH"
  fi

  echo "==> Add common users to docker group"
  if [ -n "${SUDO_USER-}" ] && id -u "$SUDO_USER" >/dev/null 2>&1; then
    usermod -aG docker "$SUDO_USER" || true
  fi
  for u in ubuntu debian admin ec2-user; do
    if id -u "$u" >/dev/null 2>&1; then
      usermod -aG docker "$u" || true
    fi
  done
fi

# Install Tesseract OCR if enabled
if [ "${INSTALL_TESSERACT}" = "1" ] || [ "${INSTALL_TESSERACT}" = "true" ]; then
  echo "==> Installing Tesseract OCR"
  apt-get install -y --no-install-recommends tesseract-ocr libtesseract-dev libleptonica-dev
fi

echo "==> Create application directories"
mkdir -p /srv/app/{compose,logs,nginx,certs} /srv/app/.env.d

# Configure firewall if Nginx is enabled
if [ "${INSTALL_NGINX}" = "1" ] || [ "${INSTALL_NGINX}" = "true" ]; then
  echo "==> Firewall configuration"
  ufw allow 22/tcp
  ufw allow 80/tcp
  ufw allow 443/tcp
  ufw --force enable || true
fi

echo "==> Enable and start services"
if [ "${INSTALL_NGINX}" = "1" ] || [ "${INSTALL_NGINX}" = "true" ]; then
  systemctl enable --now nginx || true
fi
if [ "${INSTALL_DOCKER}" = "1" ] || [ "${INSTALL_DOCKER}" = "true" ]; then
  systemctl enable --now docker || true
fi
if [ "${INSTALL_SUPERVISOR}" = "1" ] || [ "${INSTALL_SUPERVISOR}" = "true" ]; then
  systemctl enable --now supervisor || true
fi

echo "==> Post-install: pip upgrades and user-level setup"
if command -v pip3 >/dev/null 2>&1; then
  pip3 install --no-input --upgrade pip setuptools wheel || true
fi

echo "==> Cleanup apt caches"
apt-get autoremove -y
apt-get clean

echo "==> Setup complete"
