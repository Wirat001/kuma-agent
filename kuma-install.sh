#!/bin/bash

set -e

PUSH_URL="${1:-}"
NAME="$(hostname)"

if [ -z "$PUSH_URL" ]; then
    echo
    echo "Usage:"
    echo "  $0 <KUMA_PUSH_URL>"
    echo
    echo "Example:"
    echo "  $0 https://monitor.example.com/api/push/xxxxxxxx"
    echo
    exit 1
fi

if [ "$EUID" -ne 0 ]; then
    echo "Please run this script as root or with sudo."
    exit 1
fi

# Basic URL validation
if [[ "$PUSH_URL" != https://* ]]; then
    echo "Error: Push URL must start with https://"
    exit 1
fi

if [[ "$PUSH_URL" != */api/push/* ]]; then
    echo "Error: Invalid Uptime Kuma Push URL."
    echo "Expected format:"
    echo "https://your-kuma-domain/api/push/TOKEN"
    exit 1
fi

echo "======================================"
echo " Uptime Kuma Agent Installer"
echo "======================================"
echo
echo "Hostname : $NAME"
echo "Push URL : $PUSH_URL"
echo "Interval : 60 seconds"
echo

echo "[1/5] Checking curl..."

if ! command -v curl >/dev/null 2>&1; then
    echo "curl not found. Installing..."

    if command -v apt-get >/dev/null 2>&1; then
        apt-get update
        apt-get install -y curl
    else
        echo "Error: apt-get is not available."
        echo "Please install curl manually."
        exit 1
    fi
else
    echo "curl is already installed."
fi

echo
echo "[2/5] Creating configuration..."

mkdir -p /etc/kuma

cat > /etc/kuma/heartbeat.conf <<EOF
PUSH_URL="$PUSH_URL"
NAME="$NAME"
EOF

chmod 600 /etc/kuma/heartbeat.conf

echo "Configuration created:"
echo "/etc/kuma/heartbeat.conf"

echo
echo "[3/5] Creating heartbeat script..."

cat > /usr/local/bin/kuma-heartbeat.sh <<'EOF'
#!/bin/bash

set -a
source /etc/kuma/heartbeat.conf
set +a

curl -fsS \
    --max-time 15 \
    "$PUSH_URL" \
    >/dev/null
EOF

chmod 700 /usr/local/bin/kuma-heartbeat.sh

echo "Heartbeat script created."

echo
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

echo "Systemd service created."

echo
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

    echo
    echo "Uptime Kuma heartbeat is working."

else

   echo "======================================"
    echo " Installation successful"
    echo "======================================"
    echo
    echo "Check logs:"
    echo "journalctl -u kuma-heartbeat.service -n 50"
    exit 1
fi

