#!/bin/bash
# =============================================================================
# install-node-exporter.sh
# Installs Node Exporter on an external/target machine to be monitored
# by Prometheus.
#
# Usage: bash install-node-exporter.sh
#
# After running this script, add the machine's IP to prometheus.yml:
#   - job_name: 'external-server-1'
#     static_configs:
#       - targets: ['<THIS-MACHINE-IP>:9100']
# =============================================================================

set -e

NODE_EXPORTER_VERSION="1.7.0"
ARCH="linux-amd64"
FILENAME="node_exporter-${NODE_EXPORTER_VERSION}.${ARCH}"
DOWNLOAD_URL="https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/${FILENAME}.tar.gz"

echo "──────────────────────────────────────────────"
echo " Node Exporter v${NODE_EXPORTER_VERSION} Installation"
echo "──────────────────────────────────────────────"

# Step 1: Download
echo "[1/5] Downloading Node Exporter..."
wget -q --show-progress "$DOWNLOAD_URL" -O /tmp/${FILENAME}.tar.gz

# Step 2: Extract
echo "[2/5] Extracting..."
tar -xvzf /tmp/${FILENAME}.tar.gz -C /tmp/

# Step 3: Move binary to system path
echo "[3/5] Installing binary..."
sudo cp /tmp/${FILENAME}/node_exporter /usr/local/bin/
sudo chmod +x /usr/local/bin/node_exporter

# Step 4: Create systemd service
echo "[4/5] Creating systemd service..."
sudo tee /etc/systemd/system/node_exporter.service > /dev/null <<EOF
[Unit]
Description=Node Exporter
Documentation=https://prometheus.io/docs/guides/node-exporter/
After=network-online.target

[Service]
User=nobody
ExecStart=/usr/local/bin/node_exporter
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

# Step 5: Enable and start service
echo "[5/5] Starting Node Exporter service..."
sudo systemctl daemon-reload
sudo systemctl enable node_exporter
sudo systemctl start node_exporter

echo ""
echo "✅ Node Exporter installed and running!"
echo ""
sudo systemctl status node_exporter --no-pager
echo ""

# Show this machine's IP
IP=$(hostname -I | awk '{print $1}')
echo "──────────────────────────────────────────────────────────────────"
echo " This machine's IP: $IP"
echo ""
echo " Add the following to your prometheus.yml on the Prometheus server:"
echo ""
echo "   - job_name: 'external-server'"
echo "     static_configs:"
echo "       - targets: ['${IP}:9100']"
echo ""
echo " Then reload Prometheus:"
echo "   curl -X POST http://<PROMETHEUS-SERVER-IP>:9090/-/reload"
echo "──────────────────────────────────────────────────────────────────"
