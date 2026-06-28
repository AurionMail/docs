#!/bin/bash

# Make the script strict: exit immediately if a command fails
set -e

# Check for root privileges
if [ "$EUID" -ne 0 ]; then
  echo "❌ Please run this script as root (sudo ./install.sh)"
  exit 1
fi

# Check for required tools
for cmd in curl jq tar mkdir chown chmod; do
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
echo "🚀 Starting Aurion Vault SPA Automated Installation"
echo "=============================================================="

# ------------------------------------------------------------------------------
# 1. DIRECTORY CREATION & CLEANUP
# ------------------------------------------------------------------------------
echo "📁 Preparing production directory at $DEPLOY_DIR..."
# Clear the old deployment directory if it exists to prevent old file conflicts
rm -rf "$DEPLOY_DIR"
mkdir -p "$DEPLOY_DIR"

# ------------------------------------------------------------------------------
# 2. AUTOMATED SPA DOWNLOAD FROM PUBLIC GITHUB RELEASES
# ------------------------------------------------------------------------------
echo "📥 Fetching latest release asset from GitHub..."

# Asset name created by the GitHub Actions CI pipeline
ASSET_NAME="aurion-vault.tar.gz"
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
TEMP_TAR="/tmp/aurion-vault-$TAG_NAME.tar.gz"
curl -L -s -o "$TEMP_TAR" "$DOWNLOAD_URL"

echo "📦 Extracting production bundle into $DEPLOY_DIR..."
# Strip the root 'dist/' container directory to extract contents directly into place
tar -xzf "$TEMP_TAR" -C "$DEPLOY_DIR" --strip-components=1
rm -f "$TEMP_TAR"

echo "💾 Saved and extracted to $DEPLOY_DIR"

# ------------------------------------------------------------------------------
# 3. DYNAMIC RUNTIME CONFIGURATION INJECTION
# ------------------------------------------------------------------------------
echo "⚙️ Injecting runtime configuration into config.json..."
cat << EOF > "$DEPLOY_DIR/config.json"
{
  "AURION_API_BASE": "$AURION_API_BASE"
}
EOF
echo "✅ public/config.json generated successfully."

# ------------------------------------------------------------------------------
# 4. APPLICATION PERMISSIONS MANAGEMENT
# ------------------------------------------------------------------------------
echo "🔒 Configuring ownership and file permissions..."
# Ensure directory ownership belongs to the app user and its associated group
chown -R $APP_USER:$APP_USER "$DEPLOY_DIR"
find "$DEPLOY_DIR" -type d -exec chmod 755 {} \;
find "$DEPLOY_DIR" -type f -exec chmod 644 {} \;

# ------------------------------------------------------------------------------
# 5. APACHE STATIC HOSTING CONFIGURATION (HTTP - PORT 80)
# ------------------------------------------------------------------------------
if [ -d "/etc/apache2/sites-available" ]; then
  echo "🌐 Configuring Apache VirtualHost for SPA static routing..."
  
  # Enable required modules (specifically mod_rewrite for SPA deep-linking fallback)
  a2enmod rewrite > /dev/null 2>&1 || true
  a2enmod headers > /dev/null 2>&1 || true

  cat << EOF > /etc/apache2/sites-available/aurion-vault.conf
<VirtualHost *:80>
    ServerName $DOMAIN
    DocumentRoot $DEPLOY_DIR

    <Directory $DEPLOY_DIR>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted

        # Fallback all traffic to index.html for SPA client-side routing (Svelte 5 Runes)
        RewriteEngine On
        RewriteBase /
        RewriteRule ^index\.html$ - [L]
        RewriteCond %{REQUEST_FILENAME} !-f
        RewriteCond %{REQUEST_FILENAME} !-d
        RewriteRule . /index.html [L]
    </Directory>

    # Recommended Security Headers for the Vault Front-End
    Header always set X-Content-Type-Options "nosniff"
    Header always set X-Frame-Options "DENY"
    Header always set X-XSS-Protection "1; mode=block"

    ErrorLog \${APACHE_LOG_DIR}/aurion-vault-error.log
    CustomLog \${APACHE_LOG_DIR}/aurion-vault-access.log combined
</VirtualHost>
EOF

  a2ensite aurion-vault.conf > /dev/null 2>&1 || true
  
  echo "🔄 Restarting Apache web server..."
  systemctl restart apache2
else
  echo "⚠️ Apache2 was not detected on this system. Skipping web server configuration."
fi

SERVER_IP=$(curl -s https://ifconfig.me || echo "YOUR_SERVER_IP")

echo "=============================================================="
echo "✅ SPA VAULT INSTALLATION COMPLETED SUCCESSFULLY!"
echo "=============================================================="
echo ""
echo "🎯 NETWORK & PORTS SUMMARY:"
echo "--------------------------------------------------------------"
echo "🌐 Vault Frontend URL : http://$DOMAIN"
echo "📁 Document Root Path : $DEPLOY_DIR"
echo ""
echo "📋 TO-DO LIST (MANUAL STEPS REQUIRED TO FINISH UP):"
echo "--------------------------------------------------------------"
echo "1️⃣  FIREWALL CONFIGURATION (UFW):"
echo "   Make sure the standard HTTP port is open:"
echo "   $ sudo ufw allow 80/tcp"
echo ""
echo "2️⃣  DNS CONFIGURATION:"
echo "   Configure your public or internal DNS zone with this entry:"
echo "   📌 Type A   : $DOMAIN ➔ $SERVER_IP"
echo ""
echo "3️⃣  CRUCIAL: ENABLE ENCRYPTED TLS / HTTPS (CERTBOT):"
echo "   The application's cryptographic features (aurion-crypto-sdk / WebCrypto API)"
echo "   strictly require a secure context (HTTPS). Over plain HTTP, the app"
echo "   will throw critical runtime errors and fail to load."
echo ""
echo "   Run the following command to bind your Let's Encrypt certificates automatically:"
echo "   $ sudo certbot --apache -d $DOMAIN"
echo "=============================================================="