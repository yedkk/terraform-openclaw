#!/bin/bash
set -euo pipefail
exec > /var/log/openclaw-setup.log 2>&1

echo "=== OpenClaw setup starting ==="

# Install Docker via official convenience script
apt-get update
apt-get install -y ca-certificates curl openssl
curl -fsSL https://get.docker.com | sh
systemctl enable docker
systemctl start docker

# Create project directory
mkdir -p /opt/openclaw/tls
%{ for i in range(1, agent_count + 1) ~}
mkdir -p /opt/openclaw/agent-${i}
%{ endfor ~}

# --- Self-signed TLS certificate ---
openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 \
  -keyout /opt/openclaw/tls/key.pem -out /opt/openclaw/tls/cert.pem \
  -days 3650 -nodes -subj "/CN=openclaw" \
  -addext "subjectAltName=IP:0.0.0.0"

# --- docker-compose.yml ---
cat > /opt/openclaw/docker-compose.yml << 'COMPOSEOF'
services:
  caddy:
    image: caddy:2
    restart: unless-stopped
    ports:
      - "443:443"
%{ for i in range(2, agent_count + 1) ~}
      - "${8000 + i}:${8000 + i}"
%{ endfor ~}
    volumes:
      - /opt/openclaw/Caddyfile:/etc/caddy/Caddyfile
      - /opt/openclaw/tls:/etc/caddy/tls:ro
    networks:
      - clawnet
%{ for i in range(1, agent_count + 1) }
  openclaw-${i}:
    image: ghcr.io/openclaw/openclaw:latest
    restart: unless-stopped
    volumes:
      - /opt/openclaw/agent-${i}:/home/node/.openclaw
    deploy:
      resources:
        limits:
          memory: 2g
    command: node openclaw.mjs gateway --allow-unconfigured
    networks:
      - clawnet
%{ endfor ~}
networks:
  clawnet:
    driver: bridge
COMPOSEOF

# --- Caddyfile ---
cat > /opt/openclaw/Caddyfile << 'CADDYEOF'
{
    auto_https off
}

:443 {
    tls /etc/caddy/tls/cert.pem /etc/caddy/tls/key.pem
    reverse_proxy openclaw-1:18789
}
%{ for i in range(2, agent_count + 1) ~}

:${8000 + i} {
    tls /etc/caddy/tls/cert.pem /etc/caddy/tls/key.pem
    reverse_proxy openclaw-${i}:18789
}
%{ endfor ~}
CADDYEOF

# --- Agent configs ---
%{ for i in range(1, agent_count + 1) ~}
cat > /opt/openclaw/agent-${i}/openclaw.json << 'JSONEOF'
{
  "gateway": {
    "port": 18789,
    "bind": "lan",
    "auth": {
      "mode": "token",
      "token": "${auth_tokens[i - 1]}"
    },
    "controlUi": {
      "dangerouslyAllowHostHeaderOriginFallback": true
    }
  }
}
JSONEOF
chown -R 1000:1000 /opt/openclaw/agent-${i}
%{ endfor ~}

# Pull images first to avoid compose timeout
docker pull ghcr.io/openclaw/openclaw:latest
docker pull caddy:2

# Start all services
cd /opt/openclaw && docker compose up -d

echo "=== OpenClaw setup complete ==="
