# Application Update Guide

## Overview

This guide provides detailed steps for updating your 3-tier BMI Health Tracker web application running at http://54.245.166.96/

**Deployment Architecture:**
- **Backend**: Node.js Express API managed by PM2 (Port 3000, internal only)
- **Frontend**: React SPA built with Vite, served by Nginx (Port 80/443)
- **Database**: PostgreSQL
- **Project Directory**: `/root/single-server-3tier-webapp/`
- **Git Repository**: `https://github.com/md-sarowar-alam/single-server-3tier-webapp`

---

## Prerequisites

Before updating, ensure you have:
- SSH access to your server: `ssh root@54.245.166.96`
- Root access on the server (already logged in as root)
- Updated code ready (via Git pull or file upload)
- Backup of current deployment (optional but recommended)

---

## Update Scenarios

### Scenario 1: Backend Code Changes Only

**When to use:** Changes to backend logic, routes, calculations, API endpoints, etc.

#### Step-by-Step Process

1. **SSH into the server:**
   ```bash
   ssh root@54.245.166.96
   ```

2. **Navigate to backend directory:**
   ```bash
   cd /root/single-server-3tier-webapp/backend
   ```

3. **Get the latest code:**
   
   **Option A - Using Git:**
   ```bash
   git pull origin main
   ```
   
   **Option B - Upload files from local machine:**
   ```bash
   # Run this on your LOCAL machine (PowerShell)
   scp -r backend/src/* root@54.245.166.96:/root/single-server-3tier-webapp/backend/src/
   ```

4. **Install/Update dependencies (if package.json changed):**
   ```bash
   npm install --production
   ```

5. **Restart the backend service:**
   ```bash
   pm2 restart bmi-backend
   ```

6. **Verify the backend is running:**
   ```bash
   pm2 status
   pm2 logs bmi-backend --lines 50
   ```

7. **Test the API:**
   ```bash
   curl http://localhost:3000/api/measurements
   ```

8. **Check from browser:**
   - Navigate to http://54.245.166.96/
   - Test the application functionality
   - Check browser console for errors

#### Important Notes
- Backend changes take effect immediately after PM2 restart
- No Nginx restart needed for backend-only changes
- If the process crashes, check logs with `pm2 logs bmi-backend`
- Environment variables (`.env` file) changes also require PM2 restart

---

### Scenario 2: Frontend Code Changes Only

**When to use:** Changes to UI components, styles, client-side logic, React components, etc.

#### Step-by-Step Process

1. **SSH into the server:**
   ```bash
   ssh root@54.245.166.96
   ```

2. **Navigate to frontend directory:**
   ```bash
   cd /root/single-server-3tier-webapp/frontend
   ```

3. **Get the latest code:**
   
   **Option A - Using Git:**
   ```bash
   git pull origin main
   ```
   
   **Option B - Upload files from local machine:**
   ```bash
   # Run this on your LOCAL machine (PowerShell)
   scp -r frontend/src/* root@54.245.166.96:/root/single-server-3tier-webapp/frontend/src/
   ```

4. **Install/Update dependencies (if package.json changed):**
   ```bash
   npm install
   ```

5. **Build the frontend:**
   ```bash
   npm run build
   ```
   
   Expected output:
   ```
   vite v5.x.x building for production...
   ✓ 234 modules transformed.
   dist/index.html                   0.45 kB │ gzip:  0.30 kB
   dist/assets/index-a1b2c3d4.js   143.21 kB │ gzip: 46.15 kB
   dist/assets/index-e5f6g7h8.css   12.34 kB │ gzip:  3.21 kB
   ✓ built in 3.45s
   ```

6. **Verify build output exists:**
   ```bash
   ls -la dist/
   ```
   
   Should see: `index.html`, `assets/` directory with JS and CSS files

7. **Deploy to Nginx web root:**
   ```bash
   # Remove old files
   sudo rm -rf /var/www/bmi-health-tracker/*
   
   # Copy new build
   sudo cp -r dist/* /var/www/bmi-health-tracker/
   
   # Fix permissions
   sudo chown -R www-data:www-data /var/www/bmi-health-tracker
   sudo chmod -R 755 /var/www/bmi-health-tracker
   ```

8. **Verify deployment:**
   ```bash
   ls -la /var/www/bmi-health-tracker/
   ```

9. **Test the application:**
   - Open http://54.245.166.96/ in browser
   - **Hard refresh** to clear cache: `Ctrl+F5` (Windows) or `Cmd+Shift+R` (Mac)
   - Test all UI functionality
   - Check browser console for errors

#### Important Notes
- No Nginx restart needed (static files update immediately)
- Users may need to hard refresh to see changes (cache busting)
- Vite automatically adds hash to filenames for cache invalidation
- If changes don't appear, clear browser cache completely

---

### Scenario 3: Both Backend and Frontend Changes

**When to use:** Full-stack changes affecting both layers

#### Step-by-Step Process

1. **SSH into the server:**
   ```bash
   ssh root@54.245.166.96
   ```

2. **Navigate to project root:**
   ```bash
   cd /root/single-server-3tier-webapp
   ```

3. **Get the latest code:**
   ```bash
   git pull origin main
   ```

4. **Update Backend:**
   ```bash
   cd backend
   npm install --production
   pm2 restart bmi-backend
   pm2 logs bmi-backend --lines 20
   cd ..
   ```

5. **Update Frontend:**
   ```bash
   cd frontend
   npm install
   npm run build
   sudo rm -rf /var/www/bmi-health-tracker/*
   sudo cp -r dist/* /var/www/bmi-health-tracker/
   sudo chown -R www-data:www-data /var/www/bmi-health-tracker
   sudo chmod -R 755 /var/www/bmi-health-tracker
   cd ..
   ```

6. **Verify both services:**
   ```bash
   # Check backend
   pm2 status
   curl http://localhost:3000/api/measurements
   
   # Check frontend files
   ls -la /var/www/bmi-health-tracker/
   ```

7. **Test end-to-end:**
   - Visit http://54.245.166.96/
   - Test all functionality
   - Check both browser console and network tab

---

### Scenario 4: Database Schema Changes

**When to use:** Adding new tables, columns, constraints, or modifying database structure

#### Step-by-Step Process

1. **Create a new migration file:**
   
   On your local machine, create a new file in `backend/migrations/`:
   ```bash
   # Example: backend/migrations/003_add_user_preferences.sql
   ```
   
   Migration file format:
   ```sql
   -- Description: Add user preferences table
   -- Date: 2025-12-18
   
   CREATE TABLE IF NOT EXISTS user_preferences (
       id SERIAL PRIMARY KEY,
       user_id INTEGER REFERENCES users(id),
       theme VARCHAR(50) DEFAULT 'light',
       created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
   );
   
   CREATE INDEX idx_user_preferences_user_id ON user_preferences(user_id);
   ```

2. **Upload migration file to server:**
   ```bash
   # Run on LOCAL machine
   scp backend/migrations/003_add_user_preferences.sql root@54.245.166.96:/root/single-server-3tier-webapp/backend/migrations/
   ```

3. **SSH into server:**
   ```bash
   ssh root@54.245.166.96
   ```

4. **Navigate to backend directory:**
   ```bash
   cd /root/single-server-3tier-webapp/backend
   ```

5. **Get database password:**
   ```bash
   cat .env | grep DB_PASSWORD
   ```
   
   Or check the IMPLEMENTATION_AUTO.sh script for the password

6. **Run the migration:**
   ```bash
   PGPASSWORD=your_db_password psql -U bmi_user -d bmidb -h localhost -f migrations/003_add_user_preferences.sql
   ```
   
   Expected output:
   ```
   CREATE TABLE
   CREATE INDEX
   ```

7. **Verify migration:**
   ```bash
   PGPASSWORD=your_db_password psql -U bmi_user -d bmidb -h localhost -c "\dt"
   ```
   
   Or check table structure:
   ```bash
   PGPASSWORD=your_db_password psql -U bmi_user -d bmidb -h localhost -c "\d user_preferences"
   ```

8. **Restart backend (to ensure code uses new schema):**
   ```bash
   pm2 restart bmi-backend
   pm2 logs bmi-backend --lines 20
   ```

#### Important Notes
- **Always backup database before migrations:**
  ```bash
  pg_dump -U bmi_user -h localhost bmidb > backup_$(date +%Y%m%d_%H%M%S).sql
  ```
- Name migrations sequentially: `001_`, `002_`, `003_`, etc.
- Test migrations on a development database first
- Make migrations reversible when possible (include rollback SQL)
- Document what each migration does

---

### Scenario 5: Environment Variables / Configuration Changes

**When to use:** Changing database credentials, API keys, port numbers, etc.

#### Step-by-Step Process

1. **SSH into server:**
   ```bash
   ssh root@54.245.166.96
   ```

2. **Navigate to backend directory:**
   ```bash
   cd /root/single-server-3tier-webapp/backend
   ```

3. **Edit the .env file:**
   ```bash
   nano .env
   ```
   
   Or update specific variables:
   ```bash
   # Example: Update database password
   sed -i 's/DB_PASSWORD=old_password/DB_PASSWORD=new_password/' .env
   ```

4. **Verify changes:**
   ```bash
   cat .env
   ```

5. **Restart backend with new environment:**
   ```bash
   pm2 restart bmi-backend --update-env
   ```

6. **Check logs for connection issues:**
   ```bash
   pm2 logs bmi-backend --lines 30
   ```

7. **Test database connection:**
   ```bash
   curl http://localhost:3000/api/measurements
   ```

#### Important Notes
- Never commit `.env` file to Git
- PM2 must be restarted for env changes to take effect
- Use `--update-env` flag to ensure PM2 picks up new variables

---

### Scenario 6: Nginx Configuration Changes

**When to use:** Changing server names, proxy settings, SSL certificates, custom routes

#### Step-by-Step Process

1. **SSH into server:**
   ```bash
   ssh root@54.245.166.96
   ```

2. **Edit Nginx configuration:**
   ```bash
   sudo nano /etc/nginx/sites-available/bmi-health-tracker
   ```

3. **Test configuration syntax:**
   ```bash
   sudo nginx -t
   ```
   
   Expected output:
   ```
   nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
   nginx: configuration file /etc/nginx/nginx.conf test is successful
   ```

4. **If test passes, reload Nginx:**
   ```bash
   sudo systemctl reload nginx
   ```
   
   Or if major changes:
   ```bash
   sudo systemctl restart nginx
   ```

5. **Verify Nginx is running:**
   ```bash
   sudo systemctl status nginx
   ```

6. **Test the application:**
   ```bash
   curl -I http://54.245.166.96/
   ```

7. **Check Nginx logs if issues:**
   ```bash
   sudo tail -f /var/log/nginx/error.log
   sudo tail -f /var/log/nginx/access.log
   ```

---

### Scenario 7: Complete Redeployment

**When to use:** Major updates, fresh deployment, or when troubleshooting complex issues

#### Step-by-Step Process

1. **SSH into server:**
   ```bash
   ssh root@54.245.166.96
   ```

2. **Navigate to project directory:**
   ```bash
   cd /root/single-server-3tier-webapp
   ```

3. **Get latest code:**
   ```bash
   git pull origin main
   ```

4. **Run the automated deployment script:**
   ```bash
   chmod +x IMPLEMENTATION_AUTO.sh
   ./IMPLEMENTATION_AUTO.sh
   ```

5. **Follow the prompts:**
   - Enter your server IP/domain when asked
   - Script will automatically:
     - Install dependencies
     - Build frontend
     - Deploy to Nginx
     - Restart PM2 backend
     - Run health checks
     - Create backup

6. **Verify deployment:**
   - Check script output for any errors
   - Visit http://54.245.166.96/
   - Test all functionality

#### Important Notes
- Script creates automatic backup in `~/bmi_deployments_backup/`
- Last 5 backups are kept
- Use `--fresh` flag for clean installation:
  ```bash
  ./IMPLEMENTATION_AUTO.sh --fresh
  ```

---

## Quick Reference Commands

### Backend Operations
```bash
# Check backend status
pm2 status

# Restart backend
pm2 restart bmi-backend

# View logs (live)
pm2 logs bmi-backend

# View last 50 log lines
pm2 logs bmi-backend --lines 50

# Stop backend
pm2 stop bmi-backend

# Start backend
pm2 start bmi-backend

# Delete process (requires restart from ecosystem.config.js)
pm2 delete bmi-backend

# Save PM2 process list
pm2 save

# List all PM2 processes
pm2 list
```

### Frontend Operations
```bash
# Build frontend
cd /root/single-server-3tier-webapp/frontend
npm run build

# Quick deploy (after build)
sudo rm -rf /var/www/bmi-health-tracker/* && \
sudo cp -r dist/* /var/www/bmi-health-tracker/ && \
sudo chown -R www-data:www-data /var/www/bmi-health-tracker && \
sudo chmod -R 755 /var/www/bmi-health-tracker

# Check deployed files
ls -la /var/www/bmi-health-tracker/
```

### Database Operations
```bash
# Connect to database
psql -U bmi_user -d bmidb -h localhost

# Backup database
pg_dump -U bmi_user -h localhost bmidb > backup_$(date +%Y%m%d_%H%M%S).sql

# Restore database
psql -U bmi_user -h localhost bmidb < backup_20251218_120000.sql

# Run migration
PGPASSWORD=your_password psql -U bmi_user -d bmidb -h localhost -f migrations/00X_migration.sql

# List all tables
psql -U bmi_user -d bmidb -h localhost -c "\dt"

# View table structure
psql -U bmi_user -d bmidb -h localhost -c "\d measurements"
```

### Nginx Operations
```bash
# Test configuration
sudo nginx -t

# Reload configuration
sudo systemctl reload nginx

# Restart Nginx
sudo systemctl restart nginx

# Check status
sudo systemctl status nginx

# View error logs
sudo tail -f /var/log/nginx/error.log

# View access logs
sudo tail -f /var/log/nginx/access.log
```

### System Operations
```bash
# Check disk space
df -h

# Check memory usage
free -h

# Check running processes
ps aux | grep node

# Check open ports
sudo netstat -tlnp | grep -E '80|3000|5432'

# Check PM2 systemd service
sudo systemctl status pm2-ubuntu
```

---

## Troubleshooting

### Backend Not Responding

**Symptoms:** API calls fail, 502 Bad Gateway errors

**Solutions:**
1. Check PM2 status:
   ```bash
   pm2 status
   ```

2. Check backend logs:
   ```bash
   pm2 logs bmi-backend --lines 100
   ```

3. Restart backend:
   ```bash
   pm2 restart bmi-backend
   ```

4. Check database connection:
   ```bash
   curl http://localhost:3000/api/measurements
   ```

5. Verify environment variables:
   ```bash
   cat /root/single-server-3tier-webapp/backend/.env
   ```

6. Check if port 3000 is in use:
   ```bash
   sudo netstat -tlnp | grep 3000
   ```

### Frontend Not Updating

**Symptoms:** Changes don't appear in browser

**Solutions:**
1. Clear browser cache (Ctrl+F5)

2. Check if files were deployed:
   ```bash
   ls -la /var/www/bmi-health-tracker/
   stat /var/www/bmi-health-tracker/index.html
   ```

3. Rebuild and redeploy:
   ```bash
   cd /root/single-server-3tier-webapp/frontend
   rm -rf dist/
   npm run build
   sudo rm -rf /var/www/bmi-health-tracker/*
   sudo cp -r dist/* /var/www/bmi-health-tracker/
   sudo chown -R www-data:www-data /var/www/bmi-health-tracker
   ```

4. Check Nginx is serving correct files:
   ```bash
   curl -I http://54.245.166.96/
   ```

5. Disable Nginx caching temporarily (add to nginx config):
   ```nginx
   add_header Cache-Control "no-store, no-cache, must-revalidate";
   ```

### Database Connection Issues

**Symptoms:** Backend logs show connection errors

**Solutions:**
1. Check PostgreSQL is running:
   ```bash
   sudo systemctl status postgresql
   ```

2. Test database connection:
   ```bash
   psql -U bmi_user -d bmidb -h localhost
   ```

3. Verify credentials in `.env`:
   ```bash
   cat /root/single-server-3tier-webapp/backend/.env
   ```

4. Check PostgreSQL logs:
   ```bash
   sudo tail -f /var/log/postgresql/postgresql-*.log
   ```

5. Restart PostgreSQL:
   ```bash
   sudo systemctl restart postgresql
   ```

### PM2 Not Starting on Reboot

**Symptoms:** Backend down after server restart

**Solutions:**
1. Check PM2 startup service:
   ```bash
   sudo systemctl status pm2-ubuntu
   ```

2. Reconfigure PM2 startup:
   ```bash
   pm2 startup
   # Run the command it suggests with sudo
   pm2 save
   ```

3. Test by rebooting:
   ```bash
   sudo reboot
   # Wait 2 minutes, then SSH back as root
   pm2 status
   ```

### Nginx Returns 404

**Symptoms:** All routes return 404

**Solutions:**
1. Check Nginx configuration:
   ```bash
   sudo nginx -t
   cat /etc/nginx/sites-available/bmi-health-tracker
   ```

2. Verify site is enabled:
   ```bash
   ls -la /etc/nginx/sites-enabled/ | grep bmi
   ```

3. Check web root permissions:
   ```bash
   ls -la /var/www/bmi-health-tracker/
   ```

4. Verify index.html exists:
   ```bash
   cat /var/www/bmi-health-tracker/index.html
   ```

5. Check Nginx error logs:
   ```bash
   sudo tail -f /var/log/nginx/error.log
   ```

---

## Best Practices

### 1. Always Test Changes Locally First
- Run `npm run build` locally to catch build errors
- Test API endpoints with Postman or curl
- Use browser dev tools to debug frontend issues

### 2. Create Backups Before Major Changes
```bash
# Backup database
pg_dump -U bmi_user -h localhost bmidb > backup_before_update_$(date +%Y%m%d).sql

# Backup current deployment
mkdir -p ~/manual_backups
cp -r /root/single-server-3tier-webapp ~/manual_backups/backup_$(date +%Y%m%d_%H%M%S)
```

### 3. Use Git for Version Control
```bash
# Git is already cloned at /root/single-server-3tier-webapp
cd /root/single-server-3tier-webapp

# Pull updates
git pull origin main

# Or fetch specific branch
git fetch origin feature-branch
git checkout feature-branch
```

### 4. Monitor Application Health
```bash
# Create a simple health check script
cat > ~/check_health.sh << 'EOF'
#!/bin/bash
echo "=== Backend Status ==="
pm2 status

echo -e "\n=== Backend API Test ==="
curl -s http://localhost:3000/api/measurements | head -n 5

echo -e "\n=== Frontend Test ==="
curl -I http://54.245.166.96/ | grep HTTP

echo -e "\n=== Nginx Status ==="
sudo systemctl status nginx --no-pager -l

echo -e "\n=== Database Connection ==="
PGPASSWORD=$(grep DB_PASSWORD /root/single-server-3tier-webapp/backend/.env | cut -d= -f2) psql -U bmi_user -d bmidb -h localhost -c "SELECT COUNT(*) FROM measurements;"
EOF

chmod +x ~/check_health.sh
./check_health.sh
```

### 5. Use PM2 Ecosystem File for Consistency
The project already has `backend/ecosystem.config.js`. To use it:
```bash
cd /root/single-server-3tier-webapp/backend
pm2 delete all
pm2 start ecosystem.config.js
pm2 save
```

### 6. Implement Zero-Downtime Deployments
Use PM2's reload instead of restart:
```bash
pm2 reload bmi-backend
```

This gracefully restarts workers without dropping connections.

### 7. Set Up Monitoring (Optional)
```bash
# Install PM2 monitoring
pm2 install pm2-logrotate

# Configure log rotation
pm2 set pm2-logrotate:max_size 10M
pm2 set pm2-logrotate:retain 7
```

---

## Automation Script (Optional)

Create a simple update script for quick deployments:

```bash
cat > ~/update_app.sh << 'EOF'
#!/bin/bash

echo "=== BMI Health Tracker Update Script ==="
echo

# Parse arguments
UPDATE_BACKEND=false
UPDATE_FRONTEND=false
UPDATE_BOTH=false

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -b|--backend) UPDATE_BACKEND=true ;;
        -f|--frontend) UPDATE_FRONTEND=true ;;
        -a|--all) UPDATE_BOTH=true ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
    shift
done

if [[ "$UPDATE_BOTH" == "true" ]]; then
    UPDATE_BACKEND=true
    UPDATE_FRONTEND=true
fi

if [[ "$UPDATE_BACKEND" == "false" && "$UPDATE_FRONTEND" == "false" ]]; then
    echo "Usage: $0 [-b|--backend] [-f|--frontend] [-a|--all]"
    echo "  -b, --backend    Update backend only"
    echo "  -f, --frontend   Update frontend only"
    echo "  -a, --all        Update both backend and frontend"
    exit 1
fi

PROJECT_DIR="/root/single-server-3tier-webapp"

# Pull latest code
echo "Pulling latest code from Git..."
cd "$PROJECT_DIR"
git pull origin main

# Update Backend
if [[ "$UPDATE_BACKEND" == "true" ]]; then
    echo
    echo "=== Updating Backend ==="
    cd "$PROJECT_DIR/backend"
    npm install --production
    pm2 restart bmi-backend
    echo "Backend updated and restarted"
    pm2 logs bmi-backend --lines 10 --nostream
fi

# Update Frontend
if [[ "$UPDATE_FRONTEND" == "true" ]]; then
    echo
    echo "=== Updating Frontend ==="
    cd "$PROJECT_DIR/frontend"
    npm install
    npm run build
    
    echo "Deploying to Nginx..."
    sudo rm -rf /var/www/bmi-health-tracker/*
    sudo cp -r dist/* /var/www/bmi-health-tracker/
    sudo chown -R www-data:www-data /var/www/bmi-health-tracker
    sudo chmod -R 755 /var/www/bmi-health-tracker
    echo "Frontend updated and deployed"
fi

echo
echo "=== Update Complete ==="
echo "Application running at: http://54.245.166.96/"
EOF

chmod +x ~/update_app.sh
```

**Usage:**
```bash
# Update backend only
~/update_app.sh --backend

# Update frontend only
~/update_app.sh --frontend

# Update both
~/update_app.sh --all
```

---

## Security Considerations

1. **Keep Dependencies Updated:**
   ```bash
   cd /home/ubuntu/single-server-3tier-webapp/backend
   npm audit
   npm audit fix
   
   cd /home/ubuntu/single-server-3tier-webapp/frontend
   npm audit
   npm audit fix
   ```

2. **Secure Environment Variables:**
   ```bash
   # Ensure .env is not readable by others
   chmod 600 /root/single-server-3tier-webapp/backend/.env
   ```

3. **Enable Firewall:**
   ```bash
   sudo ufw status
   sudo ufw allow 80/tcp
   sudo ufw allow 443/tcp
   sudo ufw allow 22/tcp
   sudo ufw enable
   ```

4. **Set Up SSL (HTTPS):**
   ```bash
   # Install certbot
   sudo apt-get install certbot python3-certbot-nginx
   
   # Get SSL certificate
   sudo certbot --nginx -d yourdomain.com
   ```

---

## Support and Resources

- **Project Repository:** https://github.com/md-sarowar-alam/single-server-3tier-webapp
- **PM2 Documentation:** https://pm2.keymetrics.io/docs/usage/quick-start/
- **Nginx Documentation:** https://nginx.org/en/docs/
- **Vite Documentation:** https://vitejs.dev/guide/

---

## Change Log Template

Keep track of your updates:

```markdown
## 2025-12-18
- Updated backend route handling for measurements API
- Fixed frontend chart display bug
- Deployed to production at 14:30 UTC
- Changes: See commit abc123f

## 2025-12-17
- Added new database migration for user preferences
- Updated frontend theme switcher component
- Deployed to production at 10:15 UTC
```

---

## Conclusion

This guide covers all common update scenarios for your BMI Health Tracker application. Remember:

1. **Always test locally first**
2. **Create backups before major changes**
3. **Monitor logs after updates**
4. **Document your changes**
5. **Keep dependencies up to date**

For complex issues or questions, refer to the original `IMPLEMENTATION_GUIDE.md` or deployment documentation.
