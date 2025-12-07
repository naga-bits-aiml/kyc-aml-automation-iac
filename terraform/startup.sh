#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

echo "==> Updating apt repositories"
apt-get update -y
apt-get upgrade -y

echo "==> Installing base packages"
apt-get install -y --no-install-recommends \
  ca-certificates curl wget gnupg lsb-release software-properties-common \
  python3 python3-pip python3-venv \
  git build-essential \
  curl wget \
  nginx ufw fail2ban unattended-upgrades \
  apt-transport-https

echo "==> Installing Docker (get.docker.com script)"
if ! command -v docker >/dev/null 2>&1; then
  curl -fsSL https://get.docker.com | sh
fi

echo "==> Installing Docker Compose CLI plugin"
CLI_PLUGIN_DIR=/usr/local/lib/docker/cli-plugins
mkdir -p "$CLI_PLUGIN_DIR"
COMPOSE_PATH="$CLI_PLUGIN_DIR/docker-compose"
if [ ! -x "$COMPOSE_PATH" ]; then
  # Use the latest stable release tag for Compose v2; pin if required
  curl -SL "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64" -o "$COMPOSE_PATH"
  chmod +x "$COMPOSE_PATH"
fi

echo "==> Add common users to docker group"
# Add active sudo user (if any) and common distro users to docker group so they can run docker without sudo
if [ -n "${SUDO_USER-}" ] && id -u "$SUDO_USER" >/dev/null 2>&1; then
  usermod -aG docker "$SUDO_USER" || true
fi
for u in ubuntu debian admin ec2-user; do
  if id -u "$u" >/dev/null 2>&1; then
    usermod -aG docker "$u" || true
  fi
done

echo "==> Optional: install Tesseract OCR (may be large)"
# If INSTALL_TESSERACT is not set in environment, try to read instance metadata (GCE)
if [ -z "${INSTALL_TESSERACT-}" ]; then
  if command -v curl >/dev/null 2>&1; then
    # metadata server access; silent failure if not running on GCE
    META_VAL=$(curl -fs -H "Metadata-Flavor: Google" "http://metadata.google.internal/computeMetadata/v1/instance/attributes/INSTALL_TESSERACT" || true)
    if [ -n "$META_VAL" ]; then
      INSTALL_TESSERACT="$META_VAL"
    fi
  fi
fi

if [ "${INSTALL_TESSERACT-0}" = "1" ] || [ "${INSTALL_TESSERACT-}" = "true" ]; then
  apt-get install -y --no-install-recommends tesseract-ocr libtesseract-dev libleptonica-dev
fi

echo "==> Create application directories"
mkdir -p /srv/app/{compose,logs,nginx,certs} /srv/app/.env.d

echo "==> Firewall configuration"
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable || true

echo "==> Enable and start services"
systemctl enable --now nginx || true
systemctl enable --now docker || true

echo "==> Post-install: pip upgrades and user-level setup"
if command -v pip3 >/dev/null 2>&1; then
  pip3 install --no-input --upgrade pip setuptools wheel || true
fi

echo "==> Cleanup apt caches"
apt-get autoremove -y
apt-get clean

echo "==> Setup complete"