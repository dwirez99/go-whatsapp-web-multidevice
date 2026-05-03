# ARM Deployment Guide (Armbian HG680P / Raspberry Pi)

This guide is a future deployment runbook for running `go-whatsapp-web-multidevice` on low-power ARM devices.

It covers two deployment options:

1. **Docker Compose (recommended default)**
2. **Native binary + `systemd` (for lower overhead)**

It also includes **Cloudflare Tunnel** integration and practical hardening tips.

---

## Fast track: REST-only minimal setup (low storage/RAM)

If your device storage/RAM is tight (for example ~600MB free root storage), use this profile.

### Why this profile

- Runs **REST mode only** (`rest`)
- Avoids Docker layer/image overhead
- Uses one lightweight `systemd` service
- Adds memory and log limits for stability on small ARM boards

### 0) Assumptions

- You only need REST API (not MCP)
- Binary is available at `/opt/wa/whatsapp`
- Runtime data is stored at `/var/lib/gowa`

If your binary path is different, adjust `ExecStart` accordingly.

### 1) Install minimal runtime dependencies

```bash
sudo apt update
sudo apt install -y ffmpeg webp ca-certificates
```

### 2) Create directories

```bash
sudo mkdir -p /opt/wa
sudo mkdir -p /var/lib/gowa/storages
sudo chown -R $USER:$USER /opt/wa /var/lib/gowa
```

### 3) Create REST-only systemd service

Create `/etc/systemd/system/wa-rest.service`:

```ini
[Unit]
Description=Go WhatsApp Web Multi Device (REST only)
After=network.target

[Service]
Type=simple
WorkingDirectory=/var/lib/gowa
ExecStart=/opt/wa/whatsapp rest --port=3000 --debug=false --os=Chrome
Restart=always
RestartSec=5

# SQLite local DB (minimal setup)
Environment=DB_URI=file:storages/whatsapp.db?_foreign_keys=on

# Low-memory tuning (safe defaults for ~2GB RAM class devices)
Environment=GOMEMLIMIT=600MiB
Environment=GOGC=70
MemoryHigh=650M
MemoryMax=750M

# Keep logs bounded in journal
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

### 4) Enable and start service

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now wa-rest
sudo systemctl status wa-rest --no-pager
```

### 5) Ensure MCP is not running

```bash
sudo systemctl stop wa-mcp 2>/dev/null || true
sudo systemctl disable wa-mcp 2>/dev/null || true
```

### 6) Disk + memory quick maintenance

```bash
sudo apt clean
sudo apt autoremove -y
sudo journalctl --vacuum-size=50M
```

### 7) Verify REST endpoint

- Local: `http://127.0.0.1:3000/health`
- LAN: `http://<device-ip>:3000/health`

### 8) Optional: move media out of root partition

On low-storage systems, media can fill root FS quickly.
Move media to external storage and symlink/bind mount it.

---

## 1) Choose deployment mode

### Use Docker Compose when

- You want easiest maintenance and updates
- You need reproducible environment
- Your device has enough RAM/storage (recommended for Raspberry Pi 4/5)

### Use Native Binary + systemd when

- Device resources are tight (common on older HG680P units)
- You want minimal runtime overhead
- You are comfortable managing dependencies manually

---

## 2) Hardware/OS recommendations

- Prefer **64-bit OS** (`aarch64`) for both Armbian and Raspberry Pi OS
- Use **SSD** for persistent data if possible (better durability than microSD for SQLite writes)
- Keep a small swap enabled to reduce OOM risk
- Ensure stable power supply (especially for Pi + external storage)

---

## 3) Option A — Docker Compose deployment (recommended)

### 3.1 Prerequisites

```bash
sudo apt update
sudo apt install -y docker.io docker-compose-plugin
sudo systemctl enable --now docker
```

(Optional) allow running docker without `sudo`:

```bash
sudo usermod -aG docker $USER
```

Log out/in after adding user to docker group.

### 3.2 Deploy

```bash
cd /opt
git clone https://github.com/aldinokemal/go-whatsapp-web-multidevice.git
cd go-whatsapp-web-multidevice
docker compose pull
docker compose up -d
```

### 3.3 Verify

```bash
docker compose ps
docker compose logs --tail=100 nginx
docker compose logs --tail=100 whatsapp
```

Your host endpoint should be available at:

- `http://<device-ip>:3000`

> In this repository, `nginx` exposes host port `3000` and proxies to internal services.

---

## 4) Option B — Native binary + systemd (resource-efficient)

### 4.1 Prerequisites

```bash
sudo apt update
sudo apt install -y ffmpeg webp ca-certificates
```

### 4.2 Install binary

Use one of these approaches:

- Download ARM release binary from project releases, or
- Build from source on device

Build from source example:

```bash
cd /opt
git clone https://github.com/aldinokemal/go-whatsapp-web-multidevice.git
cd go-whatsapp-web-multidevice/src
go build -o /usr/local/bin/whatsapp .
```

### 4.3 Create working directory

```bash
sudo mkdir -p /var/lib/gowa/storages
sudo mkdir -p /etc/gowa
sudo chown -R $USER:$USER /var/lib/gowa /etc/gowa
```

### 4.4 Create systemd service

Create file: `/etc/systemd/system/gowa.service`

```ini
[Unit]
Description=Go WhatsApp Web Multi Device
After=network.target

[Service]
Type=simple
WorkingDirectory=/var/lib/gowa
ExecStart=/usr/local/bin/whatsapp rest --port=3000 --debug=false --os=Chrome
Restart=always
RestartSec=5
Environment=DB_URI=file:storages/whatsapp.db?_foreign_keys=on
# Optional: hardening
NoNewPrivileges=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
```

Enable and start:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now gowa
sudo systemctl status gowa
```

---

## 5) Cloudflare Tunnel integration

Two good patterns:

1. **Host cloudflared (recommended for uptime)**
2. **Docker cloudflared sidecar (all-in-compose)**

### 5.1 Host cloudflared pattern

Create tunnel + DNS route (after cloudflared install/login):

```bash
cloudflared tunnel create gowa-api
cloudflared tunnel route dns gowa-api wa-api.yourdomain.com
```

`~/.cloudflared/config.yml` example:

```yaml
tunnel: gowa-api
credentials-file: /home/<user>/.cloudflared/<TUNNEL-UUID>.json
ingress:
  - hostname: wa-api.yourdomain.com
    service: http://localhost:3000
  - service: http_status:404
```

Run:

```bash
cloudflared tunnel run gowa-api
```

### 5.2 Docker sidecar pattern

Add `cloudflared` service to compose and point origin to `http://nginx:80` (same docker network).

Use a token-based setup and keep token in environment/secret storage.

---

## 6) Security checklist

- Keep API protected with `--basic-auth` / `APP_BASIC_AUTH`
- Restrict inbound ports (only required services)
- Prefer HTTPS via Cloudflare Tunnel public hostname
- Keep system packages and container images updated
- Back up `storages` directory regularly

Webhook note:

- If webhook TLS verification fails in tunnel-based environments, this project supports:
  - `--webhook-insecure-skip-verify=true`
  - `WHATSAPP_WEBHOOK_INSECURE_SKIP_VERIFY=true`
- Use insecure skip verify only when needed.

---

## 7) Maintenance and operations

### Docker mode updates

```bash
cd /opt/go-whatsapp-web-multidevice
git pull
docker compose pull
docker compose up -d
```

### Native mode updates

```bash
cd /opt/go-whatsapp-web-multidevice
git pull
cd src
go build -o /usr/local/bin/whatsapp .
sudo systemctl restart gowa
```

### Health checks

- Health endpoint: `GET /health`
- Verify tunnel URL returns healthy response
- Monitor logs (`docker compose logs` or `journalctl -u gowa -f`)

---

## 8) Recommended default profile

For most users:

- **Raspberry Pi 4/5:** Docker Compose + host `cloudflared`
- **Armbian HG680P:** Start with Docker Compose, move to native systemd only if resource pressure appears

This gives the best balance between reliability, maintainability, and performance.
