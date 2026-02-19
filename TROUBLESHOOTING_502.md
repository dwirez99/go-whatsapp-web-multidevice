# 502 Bad Gateway Troubleshooting Guide

## What Fixed It

I've made the following changes to fix the 502 Bad Gateway error:

### 1. **Created All Required Directories**
The app needs these directories to exist at startup:
```
/app/storages/          - SQLite databases
/app/statics/           - Static assets
/app/statics/qrcode/    - QR code images
/app/statics/senditems/ - Media processing temporary files
/app/statics/media/     - Downloaded media files
```

**Previous Issue**: These directories didn't exist, causing the app to crash on startup with permission errors.

### 2. **Added Startup Diagnostics**
Created `docker/entrypoint.sh` to:
- Verify the binary exists
- Create directories with proper permissions
- Display environment variables for debugging
- Show startup logs clearly

### 3. **Added Health Check**
Added Docker HEALTHCHECK to detect crashes:
```dockerfile
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:3000/ || exit 1
```

### 4. **Improved Dependencies**
Added missing packages in Alpine Linux:
- `bash` - for entrypoint script
- `curl` - for health checks

## Why You Got 502

When the container starts:
1. The application tries to initialize SQLite databases
2. The app creates folders during `initApp()` function
3. If folders can't be created → app crashes → port 3000 becomes unavailable
4. Nginx reverse proxy tries to connect to port 3000
5. No service listening → **502 Bad Gateway**

## Next Steps to Deploy

1. **Trigger a new build** on Zeabur:
   - Push changes: `git push origin main`
   - Or manually trigger rebuild in Zeabur dashboard

2. **Check the startup logs** during deployment:
   - Look for the `[STARTUP]` messages in runtime logs
   - Verify all directories are created
   - Check that the binary is found

3. **Monitor health** after deployment:
   - Initial health check takes ~40 seconds (start-period)
   - Should start responding to requests after that
   - Check: `curl https://whatsapp-apis.zeabur.app/`

## Debugging If Still Getting 502

If you still see 502 after redeployment, check these in Zeabur runtime logs:

### Check 1: Application Started
```
Look for: "[STARTUP] WhatsApp Go Multi-Device Service"
```

### Check 2: Directories Created
```
Look for: "[STARTUP] Creating required directories..."
```

### Check 3: Binary Found
```
Look for: "[STARTUP] ✓ Binary found: /app/whatsapp"
```

### Check 4: Port Binding
```
Look for: "Starting application"
           "Listening on port 3000"
```

## Environment Variables (Optional)

You can configure via environment variables in Zeabur:

```
APP_PORT=3000                    # Default: 3000
APP_HOST=0.0.0.0                # Default: 0.0.0.0
APP_DEBUG=false                  # Enable debug logging
WHATSAPP_LOG_LEVEL=ERROR         # Debug, Info, Warning, Error
```

## Volume Configuration (Important!)

**Don't forget to create a persistent volume!**

In Zeabur dashboard:
1. Go to your service settings
2. Add Volume:
   - **Mount Path**: `/app/storages`
   - **Size**: 5-10 GB
   - **Name**: `whatsapp-storages`

Without this, you'll lose your WhatsApp connection data after each restart!

## API Endpoints After Fix

Once running, access these endpoints:

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/` | Web UI |
| POST | `/devices` | Create WhatsApp device |
| GET | `/devices` | List devices |
| POST | `/send/text` | Send text message |
| POST | `/send/image` | Send image |
| POST | `/send/video` | Send video |
| GET | `/user/:deviceId` | Get user info |
| GET | `/group` | List groups |

## Common Issues

### Still Getting 502?
1. Wait 60 seconds after deployment for initialization
2. Check if volume is created for `/app/storages`
3. Verify logs show no errors

### "Connection refused"?
1. Port 3000 is correctly exposed to "web" domain ✓
2. Health check might still be loading

### Missing WhatsApp devices after restart?
1. You didn't create a persistent volume
2. See "Volume Configuration" section above

## File Changes Made

- `docker/golang.Dockerfile` - Updated with directory creation and health check
- `docker/entrypoint.sh` - Created new startup script for diagnostics

Both files are committed to git. Deploy by pushing to your repository!
