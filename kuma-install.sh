#!/bin/bash

set -e

KUMA_URL="https://monitor.wirat.ovh"
TOKEN="${1:-}"

NAME="$(hostname)"

if [ -z "$TOKEN" ]; then
    echo
    echo "Usage:"
    echo "  $0 <KUMA_PUSH_TOKEN>"
    echo
    echo "Example:"
    echo "  $0 abc123xyz"
    echo
    exit 1
fi

if [ "$EUID" -ne 0 ]; then
    echo "Please run this script as root or with sudo."
    exit 1
fi

echo "======================================"
echo " Uptime Kuma Agent Installer"
echo "======================================"
echo
echo "Hostname : $NAME"
echo "Kuma     : $KUMA_URL"
echo

echo "[1/5] Checking curl..."

if ! command -v curl >/dev/null 2>&1; then
    echo "Installing curl..."
    apt-get update
    apt-get install -y curl
fi

echo "[2/5] Creating configuration..."

mkdir -p /etc/kuma

cat > /etc/kuma/heartbeat.conf <<EOF
KUMA_URL="$KUMA_URL"
TOKEN="$TOKEN"
NAME="$NAME"
EOF

chmod 600 /etc/kuma/heartbeat.conf

echo "[3/5] Creating heartbeat script..."

cat > /usr/local/bin/kuma-heartbeat.sh <<'EOF'
#!/bin/bash

set -a
source /etc/kuma/heartbeat.conf
set +a

curl -fsS \
    --max-time 15 \
    "${KUMA_URL}/api/push/${TOKEN}" \
    >/dev/null
EOF

chmod 700 /usr/local/bin/kuma-heartbeat.sh

echo "[4/5] Creating systemd service..."

cat > /etc/systemd/system/kuma-heartbeat.service <<EOF
[Unit]
Description=Uptime Kuma Heartbeat - $NAME
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/kuma-heartbeat.sh
EOF

echo "[5/5] Creating systemd timer..."

cat > /etc/systemd/system/kuma-heartbeat.timer <<EOF
[Unit]
Description=Uptime Kuma Heartbeat Timer - $NAME

[Timer]
OnBootSec=30s
OnUnitActiveSec=60s
Unit=kuma-heartbeat.service

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now kuma-heartbeat.timer

echo
echo "Testing heartbeat..."
echo

if systemctl start kuma-heartbeat.service; then

    echo "======================================"
    echo " Installation successful"
    echo "======================================"
    echo
    echo "Hostname : $NAME"
    echo "Interval : 60 seconds"
    echo
    echo "Timer status:"
    systemctl is-active kuma-heartbeat.timer

    echo
    echo "Next heartbeat:"
    systemctl list-timers kuma-heartbeat.timer --no-legend

else

    echo
    echo "Heartbeat test failed."
    echo
    echo "Check logs with:"
    echo "journalctl -u kuma-heartbeat.service -n 50"
    exit 1
fi
