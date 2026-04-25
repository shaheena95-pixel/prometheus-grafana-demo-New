# Prometheus + Grafana Monitoring Stack — Complete Setup Guide

> **Goal:** Set up a full monitoring stack using Prometheus, Grafana, Node Exporter, and cAdvisor — all managed via Portainer on Docker.

---

## Architecture Overview

```
[ Node Exporter :9100 ]  ──────┐
[ cAdvisor      :8080 ]  ──────┤──► [ Prometheus :9090 ] ──► [ Grafana :3000 ]
[ External Node :9100 ]  ──────┘
                                         ▲
                              [ prometheus.yml config ]

All containers managed via:
[ Portainer :9000 ]
```

| Component     | Port | Purpose                        |
|---------------|------|--------------------------------|
| Portainer     | 9000 | Docker UI / Stack deployment   |
| Prometheus    | 9090 | Metrics collection & storage   |
| Grafana       | 3000 | Dashboards & visualisation     |
| Node Exporter | 9100 | Host / OS metrics              |
| cAdvisor      | 8080 | Docker container metrics       |

---

## Prerequisites

- A Linux server (Ubuntu 20.04 / 22.04 recommended)
- Docker installed ([install guide](#step-0-install-docker))
- Minimum 2 GB RAM, 10 GB disk

---

## Step 0 — Install Docker

```bash
# Update packages
sudo apt-get update

# Install required packages
sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Add Docker's GPG key
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
    sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Add Docker repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io

# Verify Docker is running
sudo systemctl status docker

# (Optional) Run Docker without sudo
sudo usermod -aG docker $USER
newgrp docker
```

---

## Step 1 — Install Portainer

Portainer is the Docker management UI. We will use it to deploy our full monitoring stack via a compose file.

### 1.1 — Create Portainer data volume

```bash
docker volume create portainer_data
```

### 1.2 — Run Portainer container

```bash
docker run -d \
  -p 8000:8000 \
  -p 9000:9000 \
  --name portainer \
  --restart=always \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v portainer_data:/data \
  portainer/portainer-ce:latest
```

### 1.3 — Restart Docker (required after Portainer install)

```bash
sudo service docker restart
```

### 1.4 — Open Portainer in browser

```
http://<YOUR-SERVER-IP>:9000
```

- Create an admin username and password on first login
- Select **"Get Started"** → **Local** environment

---

## Step 2 — Create the Prometheus Configuration File

This config file tells Prometheus **what to scrape** and **how often**. It must exist on the host before the stack is deployed.

### 2.1 — Create the directory

```bash
sudo mkdir -p /etc/prometheus
```

### 2.2 — Create the config file

```bash
sudo vi /etc/prometheus/prometheus.yml
```

Paste the following content (also available in `configs/prometheus.yml` in this repo):
```yaml
global:
  scrape_interval: 15s   # Default: scrape every 15 seconds

scrape_configs:

  # Job 1: Prometheus scrapes itself
  - job_name: 'prometheus'
    scrape_interval: 5s
    static_configs:
      - targets: ['localhost:9090']

  # Job 2: Node Exporter — collects host/OS metrics
  - job_name: 'node_exporter'
    static_configs:
      - targets: ['node_exporter:9100']

  # Job 3: cAdvisor — collects Docker container metrics
  - job_name: 'cadvisor'
    static_configs:
      - targets: ['cadvisor:8080']
```


> **Note:** `node_exporter` and `cadvisor` use container names as hostnames because all services run in the same Docker network.

### 2.3 — Verify the file was saved correctly

```bash
cat /etc/prometheus/prometheus.yml
```

---

## Step 3 — Deploy the Monitoring Stack via Portainer

### 3.1 — Open Portainer and go to Stacks

```
http://<YOUR-SERVER-IP>:9000
```

Navigate to: **Home → Local → Stacks → + Add Stack**

### 3.2 — Name the stack

Enter name: `monitoring`

### 3.3 — Paste the Docker Compose file

In the **Web editor** tab, paste the content from `configs/docker-compose.yml` (also shown below):

```yaml
version: '3'

volumes:
  prometheus-data:
    driver: local
  grafana-data:
    driver: local

services:

  # ── Prometheus ──────────────────────────────────────────────
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    ports:
      - "9090:9090"
    volumes:
      - /etc/prometheus:/etc/prometheus          # mounts our config file
      - prometheus-data:/prometheus              # stores time-series data
    restart: unless-stopped
    command:
      - "--config.file=/etc/prometheus/prometheus.yml"

  # ── Grafana ─────────────────────────────────────────────────
  grafana:
    image: grafana/grafana-oss:latest
    container_name: grafana
    ports:
      - "3000:3000"
    volumes:
      - grafana-data:/var/lib/grafana            # stores dashboards & settings
    restart: unless-stopped

  # ── Node Exporter ───────────────────────────────────────────
  node_exporter:
    image: quay.io/prometheus/node-exporter:latest
    container_name: node_exporter
    command:
      - '--path.rootfs=/host'
    pid: host
    restart: unless-stopped
    volumes:
      - '/:/host:ro,rslave'                      # read-only access to host filesystem

  # ── cAdvisor ────────────────────────────────────────────────
  cadvisor:
    image: gcr.io/cadvisor/cadvisor
    container_name: cadvisor
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:ro
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro
      - /dev/disk/:/dev/disk:ro
    devices:
      - /dev/kmsg
    restart: unless-stopped
```

### 3.4 — Deploy the stack

Click **"Deploy the stack"** at the bottom.

### 3.5 — Verify all containers are running

In Portainer, go to **Containers**. You should see all 4 containers with status **"running"**:

```
✅ prometheus
✅ grafana
✅ node_exporter
✅ cadvisor
```

---

## Step 4 — Verify Prometheus

### 4.1 — Open Prometheus UI

```
http://<YOUR-SERVER-IP>:9090
```

### 4.2 — Check all targets are UP

Go to: **Status → Targets**

You should see 3 targets all showing state **UP**:

```
prometheus    → http://localhost:9090/metrics         ✅ UP
node_exporter → http://node_exporter:9100/metrics     ✅ UP
cadvisor      → http://cadvisor:8080/metrics          ✅ UP
```

### 4.3 — Run a quick test query

In the Prometheus query box, try:

```promql
up
```

This returns `1` for every healthy target. Try also:

```promql
node_cpu_seconds_total
container_memory_usage_bytes
```

---

## Step 5 — Configure Grafana

### 5.1 — Open Grafana

```
http://<YOUR-SERVER-IP>:3000
```

Default credentials:
- **Username:** `admin`
- **Password:** `admin`

(Grafana will prompt you to change the password on first login.)

### 5.2 — Add Prometheus as a data source

1. Go to: **⚙️ Configuration → Data Sources**
2. Click **"Add data source"**
3. Select **Prometheus**
4. In the **URL** field enter:
   ```
   http://<YOUR-SERVER-IP>:9090
   ```
5. Scroll down → Click **"Save & Test"**
6. You should see: ✅ **"Data source is working"**

### 5.3 — Import the Node Exporter Dashboard

1. Go to: **Dashboards → Import**
2. In **"Import via grafana.com"** enter code:
   ```
   1860
   ```
3. Click **Load**
4. Under **"Prometheus"** dropdown → select your Prometheus data source
5. Click **Import**

You now have a full **Node Exporter Full** dashboard showing:
- CPU usage
- Memory usage
- Disk I/O
- Network traffic
- System load

### 5.4 — Import the Docker / cAdvisor Dashboard

1. Go to: **Dashboards → Import**
2. Enter code:
   ```
   193
   ```
3. Click **Load**
4. Select Prometheus as the data source
5. Click **Import**

You now have a **Docker monitoring** dashboard showing all container metrics.

---

## Step 6 — Add an External Server (Optional)

To monitor a **second machine**, install Node Exporter on it.

### 6.1 — On the external/target machine

```bash
# Download Node Exporter
wget https://github.com/prometheus/node_exporter/releases/download/v1.7.0/node_exporter-1.7.0.linux-amd64.tar.gz

# Extract
tar -xvzf node_exporter-1.7.0.linux-amd64.tar.gz

# Move into the directory
cd node_exporter-1.7.0.linux-amd64

# Run Node Exporter
./node_exporter
```

Verify it is running:

```bash
curl http://localhost:9100/metrics
```

### 6.2 — Run Node Exporter as a background service (optional but recommended)

```bash
# Move binary to system path
sudo cp node_exporter /usr/local/bin/

# Create a systemd service
sudo vi /etc/systemd/system/node_exporter.service
```

Paste:

```ini
[Unit]
Description=Node Exporter
After=network.target

[Service]
User=nobody
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable node_exporter
sudo systemctl start node_exporter
sudo systemctl status node_exporter
```

### 6.3 — Add the external server to Prometheus config

On your **Prometheus server**, edit the config:

```bash
sudo vi /etc/prometheus/prometheus.yml
```

Add a new job at the bottom:

```yaml
  # Job 4: External server
  - job_name: 'external-server-1'
    static_configs:
      - targets: ['<EXTERNAL-SERVER-IP>:9100']
```

### 6.4 — Reload Prometheus config (no restart needed)

```bash
curl -X POST http://localhost:9090/-/reload
```

### 6.5 — Verify new target in Prometheus

Go to: **Prometheus → Status → Targets**

The external server should appear as **UP**.

---

## Dashboard Reference

| Dashboard Name         | Import Code | Data Source | What it shows                |
|------------------------|-------------|-------------|------------------------------|
| Node Exporter Full     | `1860`      | Prometheus  | CPU, RAM, disk, network      |
| Docker Containers      | `193`       | Prometheus  | Container CPU, RAM, network  |
| Node Exporter (alt)    | `1830`      | Prometheus  | Alternative node metrics     |
| cAdvisor (detailed)    | `14282`     | Prometheus  | Detailed container metrics   |

---

## Useful Prometheus Queries (PromQL)

```promql
# Check all targets are up
up

# CPU usage percentage per core
100 - (avg by(cpu) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Total memory available
node_memory_MemAvailable_bytes

# Disk usage percentage
(node_filesystem_size_bytes - node_filesystem_free_bytes) / node_filesystem_size_bytes * 100

# Container CPU usage
rate(container_cpu_usage_seconds_total[5m])

# Container memory usage
container_memory_usage_bytes
```

---

## Troubleshooting

| Problem | Solution |
|---|---|
| Portainer not opening | Check `docker ps` — portainer container must be running |
| Prometheus targets showing DOWN | Check container names match `prometheus.yml` targets exactly |
| Grafana "Data source not working" | Verify Prometheus URL is correct and accessible |
| cAdvisor not starting | Ensure `/dev/kmsg` exists on host |
| Node Exporter missing metrics | Check `pid: host` is set in compose file |

## Basic Troubleshooting

This is where you stand out:

Target not showing → check /targets
Metrics missing → check exporter
High memory → retention tuning
Wrong data → query issue

### Check container logs

```bash
docker logs prometheus
docker logs grafana
docker logs node_exporter
docker logs cadvisor
```

### Restart a single container

```bash
docker restart prometheus
```

### Restart the entire stack (from Portainer)

Go to: **Stacks → monitoring → Stop → Start**

---

## Repo Structure

```
prometheus-grafana-demo/
│
├── README.md                        ← This file (full guide)
│
├── configs/
│   ├── prometheus.yml               ← Prometheus scrape config
│   └── docker-compose.yml           ← Full monitoring stack
│
└── scripts/
    ├── install-docker.sh            ← Docker install script
    └── install-node-exporter.sh     ← Node Exporter install (external servers)
```

---

## Quick Start Checklist

```
[ ] Step 0 — Docker installed and running
[ ] Step 1 — Portainer running on :9000
[ ] Step 2 — /etc/prometheus/prometheus.yml created
[ ] Step 3 — Monitoring stack deployed via Portainer
[ ] Step 4 — All 3 Prometheus targets showing UP on :9090
[ ] Step 5 — Grafana configured with Prometheus data source on :3000
[ ] Step 5 — Dashboard 1860 imported (Node Exporter)
[ ] Step 5 — Dashboard 193 imported (Docker)
[ ] Step 6 — (Optional) External server added and showing in targets
```
