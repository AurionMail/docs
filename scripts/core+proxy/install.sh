#!/bin/bash

# Make the script strict: exit immediately if a command fails
set -e

# Check for root privileges
if [ "$EUID" -ne 0 ]; then
  echo "❌ Please run this script as root (sudo ./install.sh)"
  exit 1
fi

# Load the configuration file
CONFIG_FILE="install.conf"
if [ ! -f "$CONFIG_FILE" ]; then
  echo "❌ Configuration file $CONFIG_FILE not found!"
  exit 1
fi
source "$CONFIG_FILE"

echo "=============================================================="
echo "🚀 Starting Aurion Core & Proxy Installation"
echo "=============================================================="

# Verify that the required compiled binaries are present
if [ ! -f "./aurion-core" ] || [ ! -f "./aurion-proxy" ]; then
  echo "❌ The compiled binaries 'aurion-core' and 'aurion-proxy' must be present in this directory."
  exit 1
fi

# Automatically generate AUTH_FAKE_SALT_SECRET if not defined
if [ -z "$AUTH_FAKE_SALT_SECRET" ]; then
  echo "🔑 Generating a secure AUTH_FAKE_SALT_SECRET..."
  AUTH_FAKE_SALT_SECRET=$(openssl rand -base64 32)
fi

# ------------------------------------------------------------------------------
# 1. DIRECTORY CREATION AND BINARY DEPLOYMENT
# ------------------------------------------------------------------------------
echo "📁 Creating production directories..."
mkdir -p "$CORE_DIR"
mkdir -p "$PROXY_DIR"

echo "📦 Deploying binaries..."
cp ./aurion-core "$CORE_DIR/"
cp ./aurion-proxy "$PROXY_DIR/"

# ------------------------------------------------------------------------------
# 2. PRODUCTION .ENV FILE GENERATION
# ------------------------------------------------------------------------------
echo "📝 Generating .env file for Aurion Core..."
cat << EOF > "$CORE_DIR/.env"
APP_ENV=$CORE_APP_ENV
APP_PORT=$CORE_APP_PORT

DB_HOST=$DB_HOST
DB_PORT=$DB_PORT
DB_USER=$DB_USER
DB_PASS=$DB_PASS
DB_NAME=$DB_NAME

MAIL_BACKEND=$MAIL_BACKEND  
JMAP_URL=$JMAP_URL
STALWART_API_KEY=$STALWART_API_KEY

AUTH_FAKE_SALT_SECRET="$AUTH_FAKE_SALT_SECRET"
EOF

echo "📝 Generating .env file for Aurion Proxy..."
cat << EOF > "$PROXY_DIR/.env"
LISTEN_ADDR=$PROXY_LISTEN_ADDR
DOMAIN=$DOMAIN
MAX_MESSAGE_BYTES=$PROXY_MAX_MESSAGE_BYTES

ROUTING_URL=http://localhost:$CORE_APP_PORT
ROUTING_TIMEOUT=3s

FORWARD_ADDR=$PROXY_FORWARD_ADDR

QUEUE_SIZE=$PROXY_QUEUE_SIZE
WORKER_COUNT=$PROXY_WORKER_COUNT
EOF

# Append TLS variables to Proxy .env if provided, otherwise append commented templates
if [ -n "$PROXY_TLS_CERT" ] && [ -n "$PROXY_TLS_KEY" ]; then
  cat << EOF >> "$PROXY_DIR/.env"

# TLS active configuration
TLS_CERT=$PROXY_TLS_CERT
TLS_KEY=$PROXY_TLS_KEY
EOF
else
  cat << EOF >> "$PROXY_DIR/.env"

# TLS configuration (Disabled by default)
# Un-comment and set these paths once your TLS certificates are available:
# TLS_CERT=/etc/letsencrypt/live/$DOMAIN/fullchain.pem
# TLS_KEY=/etc/letsencrypt/live/$DOMAIN/privkey.pem
EOF
fi

# ------------------------------------------------------------------------------
# 3. APPLICATION PERMISSIONS MANAGEMENT
# ------------------------------------------------------------------------------
echo "🔒 Configuring ownership and file permissions..."
chown -R $APP_USER:$APP_USER "$CORE_DIR"
chown -R $APP_USER:$APP_USER "$PROXY_DIR"
chmod 750 "$CORE_DIR/aurion-core"
chmod 750 "$PROXY_DIR/aurion-proxy"
chmod 600 "$CORE_DIR/.env"
chmod 600 "$PROXY_DIR/.env"

# ------------------------------------------------------------------------------
# 4. APACHE REVERSE PROXY CONFIGURATION (HTTP - PORT 80)
# ------------------------------------------------------------------------------
if [ -d "/etc/apache2/sites-available" ]; then
  echo "🌐 Configuring Apache Reverse Proxy in HTTP mode..."
  
  # Enable mandatory Apache modules
  a2enmod proxy > /dev/null 2>&1 || true
  a2enmod proxy_http > /dev/null 2>&1 || true
  a2enmod headers > /dev/null 2>&1 || true

  # Create standard HTTP VirtualHost file
  cat << EOF > /etc/apache2/sites-available/aurion.conf
<VirtualHost *:80>
    ServerName $DOMAIN

    # Forward HTTP requests to the local Go application
    ProxyPreserveHost On
    ProxyPass / http://localhost:$CORE_APP_PORT/
    ProxyPassReverse / http://localhost:$CORE_APP_PORT/

    # Basic security headers
    Header always set X-Content-Type-Options "nosniff"
    Header always set X-Frame-Options "DENY"
    Header always set X-XSS-Protection "1; mode=block"

    ErrorLog \${APACHE_LOG_DIR}/aurion-error.log
    CustomLog \${APACHE_LOG_DIR}/aurion-access.log combined
</VirtualHost>
EOF

  # Enable the virtual host and restart Apache
  a2ensite aurion.conf > /dev/null 2>&1 || true
  systemctl restart apache2
else
  echo "⚠️ Apache2 was not detected on this system. Skipping reverse proxy configuration."
fi

# ------------------------------------------------------------------------------
# 5. SYSTEMD SERVICES CONFIGURATION
# ------------------------------------------------------------------------------
echo "⚙️ Creating Systemd service: aurion (Core)..."
cat << EOF > /etc/systemd/system/aurion.service
[Unit]
Description=Aurion Core Server
After=network.target postgresql.service

[Service]
Type=simple
User=$APP_USER
WorkingDirectory=$CORE_DIR
ExecStart=$CORE_DIR/aurion-core
Restart=always
RestartSec=5
EnvironmentFile=$CORE_DIR/.env

[Install]
WantedBy=multi-user.target
EOF

echo "⚙️ Creating Systemd service: aurion-proxy (Proxy)..."
cat << EOF > /etc/systemd/system/aurion-proxy.service
[Unit]
Description=Aurion Proxy Server
After=network.target

[Service]
Type=simple
User=$APP_USER
WorkingDirectory=$PROXY_DIR
ExecStart=$PROXY_DIR/aurion-proxy
Restart=always
RestartSec=5
EnvironmentFile=$PROXY_DIR/.env

# Grant the Go binary permission to bind to privileged port 25 without root privileges
AmbientCapabilities=CAP_NET_BIND_SERVICE
CapabilityBoundingSet=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd manager and start services
echo "🔄 Reloading Systemd daemon and starting services..."
systemctl daemon-reload

systemctl enable aurion
systemctl start aurion

systemctl enable aurion-proxy
systemctl start aurion-proxy

# Fetch server's public IP for the summary report
SERVER_IP=$(curl -s https://ifconfig.me || echo "YOUR_SERVER_IP")

echo "=============================================================="
echo "✅ INSTALLATION PROGRESS COMPLETED SUCCESSFULLY!"
echo "=============================================================="
echo ""
echo "🎯 NETWORK & PORTS SUMMARY:"
echo "--------------------------------------------------------------"
echo "🌐 Core Server URL   : http://$DOMAIN"
echo "🔀 Core Local Port  : http://localhost:$CORE_APP_PORT (Proxied via Apache)"
echo "📨 SMTP Proxy Port   : $SERVER_IP:25 (Publicly listening)"
echo ""
echo "📋 TO-DO LIST (MANUAL STEPS REQUIRED TO FINISH UP):"
echo "--------------------------------------------------------------"
echo "1️⃣  DATABASE INITIALIZATION:"
echo "   Ensure you have created the database and user in PostgreSQL:"
echo "   $ sudo -u postgres psql"
echo "   > CREATE USER $DB_USER WITH PASSWORD '$DB_PASS';"
echo "   > CREATE DATABASE $DB_NAME OWNER $DB_USER;"
echo "   > \c $DB_NAME"
echo "   > GRANT ALL ON SCHEMA public TO $DB_USER;"
echo "   (Note: Embedded database migrations will automatically run once"
echo "   the database is reachable and the service restarts)."
echo ""
echo "2️⃣  FIREWALL CONFIGURATION (UFW / Iptables):"
echo "   Make sure the required ports are opened on your server:"
echo "   $ sudo ufw allow 80/tcp   (Apache HTTP)"
echo "   $ sudo ufw allow 25/tcp   (Aurion SMTP Proxy)"
echo ""
echo "3️⃣  DNS CONFIGURATION:"
echo "   Configure your public DNS zone with the following records:"
echo "   📌 Type A   : $DOMAIN ➔ $SERVER_IP"
echo "   📌 Type MX  : @ ➔ $DOMAIN (Priority 10)"
echo ""
echo "4️⃣  HOW TO ENABLE ENCRYPTED TLS FOR THE SMTP PROXY (LATER):"
echo "   If you want to secure your incoming email traffic using your shared"
echo "   domain certificates from Let's Encrypt, follow these steps:"
echo ""
echo "   A. Edit the proxy's .env file:"
echo "      $ sudo nano $PROXY_DIR/.env"
echo "   B. Un-comment or append the following lines with your cert paths:"
echo "      TLS_CERT=/etc/letsencrypt/live/$DOMAIN/fullchain.pem"
echo "      TLS_KEY=/etc/letsencrypt/live/$DOMAIN/privkey.pem"
echo "   C. Grant read permissions to the '$APP_USER' group for Let's Encrypt:"
echo "      $ sudo chown -R root:$APP_USER /etc/letsencrypt/live/"
echo "      $ sudo chown -R root:$APP_USER /etc/letsencrypt/archive/"
echo "      $ sudo chmod -R 750 /etc/letsencrypt/live/"
echo "      $ sudo chmod -R 750 /etc/letsencrypt/archive/"
echo "   D. Restart the proxy service:"
echo "      $ sudo systemctl restart aurion-proxy"
echo ""
echo "🔍 Monitor your services using:"
echo "   $ sudo systemctl status aurion"
echo "   $ sudo systemctl status aurion-proxy"
echo "   $ sudo journalctl -u aurion-proxy -f"
echo "=============================================================="