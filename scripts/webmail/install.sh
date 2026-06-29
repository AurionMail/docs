#!/bin/bash

# Make the script strict: exit immediately if a command fails
set -e

# Check for root privileges
if [ "$EUID" -ne 0 ]; then
  echo "❌ Please run this script as root (sudo ./install.sh)"
  exit 1
fi

# Check for required tools (added node and npm as runtime requirements)
for cmd in curl jq tar mkdir chown chmod node npm; do
  if ! command -v $cmd &> /dev/null; then
    echo "❌ Missing required command dependency: $cmd. Please install it first."
    exit 1
  fi
done

# Load the configuration file
CONFIG_FILE="install.conf"
if [ ! -f "$CONFIG_FILE" ]; then
  echo "❌ Configuration file $CONFIG_FILE not found!"
  exit 1
fi
source "$CONFIG_FILE"

echo "=============================================================="
echo "🚀 Starting Bulwark Webmail Automated Installation"
echo "=============================================================="

# ------------------------------------------------------------------------------
# 1. DIRECTORY CREATION & CLEANUP
# ------------------------------------------------------------------------------
echo "📁 Preparing production directory at $DEPLOY_DIR..."
# Preserve existing data directory if it exists to prevent loss of user settings
if [ -d "$DEPLOY_DIR/data" ]; then
  echo "💾 Existing data directory found. Backup and merge will be preserved."
  # Move it temporarily out of the way before clearing the root directory
  mv "$DEPLOY_DIR/data" /tmp/bulwark-data-bak
fi

rm -rf "$DEPLOY_DIR"
mkdir -p "$DEPLOY_DIR"

# Restore data if backup exists, otherwise create infrastructure directories
if [ -d "/tmp/bulwark-data-bak" ]; then
  mv /tmp/bulwark-data-bak "$DEPLOY_DIR/data"
else
  mkdir -p "$DEPLOY_DIR/data/settings" "$DEPLOY_DIR/data/admin" "$DEPLOY_DIR/data/admin-state"
fi

# ------------------------------------------------------------------------------
# 2. AUTOMATED ARTIFACT DOWNLOAD FROM PUBLIC GITHUB RELEASES
# ------------------------------------------------------------------------------
echo "📥 Fetching latest release asset from GitHub..."

# Asset name created by the GitHub Actions CI pipeline
ASSET_NAME="bulwark-webmail.tar.gz"
API_URL="https://api.github.com/repos/$GITHUB_REPO/releases/latest"

echo "🔍 Detecting latest version for $GITHUB_REPO..."
RELEASE_JSON=$(curl -s "$API_URL")

# Extract the browser download URL for the compressed asset archive
DOWNLOAD_URL=$(echo "$RELEASE_JSON" | jq -r ".assets[] | select(.name==\"$ASSET_NAME\") | .browser_download_url")

if [ -z "$DOWNLOAD_URL" ] || [ "$DOWNLOAD_URL" == "null" ]; then
  echo "❌ Error: Could not find asset '$ASSET_NAME' in the latest release of $GITHUB_REPO."
  exit 1
fi

TAG_NAME=$(echo "$RELEASE_JSON" | jq -r ".tag_name")
echo "⬇️  Downloading $ASSET_NAME ($TAG_NAME) from GitHub..."

# Download the archive into a temporary folder
TEMP_TAR="/tmp/bulwark-webmail-$TAG_NAME.tar.gz"
curl -L -s -o "$TEMP_TAR" "$DOWNLOAD_URL"

echo "📦 Extracting production bundle into $DEPLOY_DIR..."
tar -xzf "$TEMP_TAR" -C "$DEPLOY_DIR"
rm -f "$TEMP_TAR"

echo "💾 Saved and extracted to $DEPLOY_DIR"

# ------------------------------------------------------------------------------
# 3. DYNAMIC ENVIRONMENT CONFIGURATION GENERATION
# ------------------------------------------------------------------------------
echo "⚙️ Generating production .env.local configuration..."
cat << EOF > "$DEPLOY_DIR/.env.local"
# Local listen address and port
HOSTNAME=$HOSTNAME
PORT=$PORT

# JMAP configuration
JMAP_SERVER_URL=$JMAP_SERVER_URL
APP_NAME="$APP_NAME"
STALWART_FEATURES=$STALWART_FEATURES
AURION_SERVER_URL=$AURION_SERVER_URL

# Secret session key
SESSION_SECRET="$SESSION_SECRET"

# Local application data storage paths
SETTINGS_SYNC_ENABLED=true
SETTINGS_DATA_DIR=./data/settings
ADMIN_CONFIG_DIR=./data/admin
ADMIN_STATE_DIR=./data/admin-state
ADMIN_CONFIG_READONLY=false

# Logging configuration
LOG_FORMAT=text
LOG_LEVEL=info
EOF
echo "✅ .env.local generated successfully."

# ------------------------------------------------------------------------------
# 4. NODE DEPENDENCIES INSTALLATION (PRODUCTION ONLY)
# ------------------------------------------------------------------------------
echo "📦 Installing Next.js production dependencies..."
cd "$DEPLOY_DIR"

# Clean up any conflicting pre-existing artifacts
rm -rf node_modules package-lock.json

# Fix the specific root-owned cache folder issue highlighted by npm
if [ -d "/var/www/.npm" ]; then
  echo "🛡️  Fixing npm cache ownership permissions..."
  chown -R $APP_USER:$APP_USER "/var/www/.npm"
fi

# Ensure the deployment directory is fully owned by the app user
chown -R $APP_USER:$APP_USER "$DEPLOY_DIR"

# Run install with an isolated temp cache path AND ignore dev lifecycle scripts (like husky)
echo "📥 Running npm install under $APP_USER context..."
sudo -u $APP_USER npm install --omit=dev --no-audit --no-fund --ignore-scripts --cache=/tmp/.npm-cache-$APP_USER

cd - > /dev/null

# ------------------------------------------------------------------------------
# 5. APPLICATION PERMISSIONS MANAGEMENT
# ------------------------------------------------------------------------------
echo "🔒 Configuring ownership and file permissions..."
chown -R $APP_USER:$APP_USER "$DEPLOY_DIR"

# Apply safe defaults: 755 for directories, 644 for regular files
find "$DEPLOY_DIR" -type d -exec chmod 755 {} \;
find "$DEPLOY_DIR" -type f -exec chmod 644 {} \;

# RESTORE EXECUTION RIGHTS TO THE NODE BINARIES:
if [ -d "$DEPLOY_DIR/node_modules/.bin" ]; then
  echo "⚡ Restoring execution permissions for node framework binaries..."
  chmod -R 755 "$DEPLOY_DIR/node_modules/.bin"
  
  # Also fix target symlink binaries that Next.js references
  find "$DEPLOY_DIR/node_modules/next/dist/bin" -type f -exec chmod 755 {} \; 2>/dev/null || true
fi

# ------------------------------------------------------------------------------
# 6. SYSTEMD SERVICE CONFIGURATION
# ------------------------------------------------------------------------------
echo "⚙️ Configuring systemd service unit..."
cat << EOF > /etc/systemd/system/bulwark-webmail.service
[Unit]
Description=Bulwark Webmail Service
After=network.target

[Service]
Type=simple
User=$APP_USER
Group=$APP_USER
WorkingDirectory=$DEPLOY_DIR
ExecStart=$(command -v npm) start
Restart=always
RestartSec=10
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=bulwark-webmail
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOF

echo "🔄 Loading and starting bulwark-webmail daemon..."
systemctl daemon-reload
systemctl enable bulwark-webmail
systemctl restart bulwark-webmail

# ------------------------------------------------------------------------------
# 7. APACHE REVERSE PROXY CONFIGURATION (HTTP - PORT 80)
# ------------------------------------------------------------------------------
if [ -d "/etc/apache2/sites-available" ]; then
  echo "🌐 Configuring Apache Reverse Proxy with WebSockets support..."
  
  # Enable mandatory proxy modules
  a2enmod proxy > /dev/null 2>&1 || true
  a2enmod proxy_http > /dev/null 2>&1 || true
  a2enmod proxy_wstunnel > /dev/null 2>&1 || true
  a2enmod rewrite > /dev/null 2>&1 || true
  a2enmod headers > /dev/null 2>&1 || true

  cat << EOF > /etc/apache2/sites-available/bulwark-webmail.conf
<VirtualHost *:80>
    ServerName $DOMAIN

    ProxyRequests Off
    ProxyPreserveHost On
    ProxyVia Full

    <Proxy *>
        Require all granted
    </Proxy>

    # Routing rules for Next.js WebSockets (Server Actions / Subscriptions)
    RewriteEngine On
    RewriteCond %{HTTP:Upgrade} =websocket [NC]
    RewriteRule ^/(.*)           ws://$HOSTNAME:$PORT/\$1 [P,L]

    # Standard HTTP reverse proxy to the local Node.js instance
    ProxyPass / http://$HOSTNAME:$PORT/
    ProxyPassReverse / http://$HOSTNAME:$PORT/

    # Security headers for proxied sessions
    RequestHeader set X-Forwarded-Proto "http"
    RequestHeader set X-Forwarded-Port "80"

    # Additional standard hardening headers
    Header always set X-Content-Type-Options "nosniff"
    Header always set X-Frame-Options "SAMEORIGIN"

    ErrorLog \${APACHE_LOG_DIR}/bulwark-webmail-error.log
    CustomLog \${APACHE_LOG_DIR}/bulwark-webmail-access.log combined
</VirtualHost>
EOF

  a2ensite bulwark-webmail.conf > /dev/null 2>&1 || true
  
  echo "🔄 Restarting Apache web server..."
  systemctl restart apache2
else
  echo "⚠️ Apache2 was not detected on this system. Skipping reverse proxy configuration."
fi

SERVER_IP=$(curl -s https://ifconfig.me || echo "YOUR_SERVER_IP")

echo "=============================================================="
echo "✅ BULWARK WEBMAIL INSTALLATION COMPLETED SUCCESSFULLY!"
echo "=============================================================="
echo ""
echo "🎯 NETWORK & PORTS SUMMARY:"
echo "--------------------------------------------------------------"
echo "🌐 Webmail Public URL : http://$DOMAIN"
echo "⚙️  Internal Node App  : http://$HOSTNAME:$PORT"
echo "📁 Installation Path  : $DEPLOY_DIR"
echo ""
echo "📋 TO-DO LIST (MANUAL STEPS REQUIRED TO FINISH UP):"
echo "--------------------------------------------------------------"
echo "1️⃣  SESSION KEY RE-CONFIGURATION:"
echo "   If you left the default session key in 'install.conf', generate"
echo "   a unique cryptographically secure key now in $DEPLOY_DIR/.env.local :"
echo "   $ openssl rand -base64 32"
echo ""
echo "2️⃣  DNS CONFIGURATION:"
echo "   Point your domain to this server's public IP:"
echo "   📌 Type A   : $DOMAIN ➔ $SERVER_IP"
echo ""
echo "3️⃣  SSL/TLS CONFIGURATION (RECOMMENDED):"
echo "   To secure JMAP transport and cookies, activate HTTPS via Certbot:"
echo "   $ sudo certbot --apache -d $DOMAIN"
echo "=============================================================="