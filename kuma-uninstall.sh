#!/bin/bash

set -e

echo "Stopping Uptime Kuma agent..."

systemctl disable --now kuma-heartbeat.timer 2>/dev/null || true

systemctl daemon-reload

rm -f /etc/systemd/system/kuma-heartbeat.timer
rm -f /etc/systemd/system/kuma-heartbeat.service
rm -f /usr/local/bin/kuma-heartbeat.sh
rm -rf /etc/kuma

systemctl daemon-reload

echo
echo "Uptime Kuma agent removed."
