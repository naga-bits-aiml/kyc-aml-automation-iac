#!/bin/bash
apt-get update -y
apt-get upgrade -y

apt-get install -y git build-essential nginx ufw fail2ban unattended-upgrades

curl -fsSL https://get.docker.com | sh
usermod -aG docker $USER

curl -L "https://github.com/docker/compose/releases/download/2.29.2/docker-compose-linux-x86_64" \
  -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

mkdir -p /srv/app/{compose,logs,nginx,certs} /srv/app/.env.d

ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

systemctl enable nginx
systemctl start nginx
systemctl enable docker
systemctl start docker