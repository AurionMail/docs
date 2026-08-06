#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# 0. INITIAL SECURITY & PREREQUISITE CHECKS
# -----------------------------------------------------------------------------
if [ "$EUID" -ne 0 ]; then
  echo "❌ This script must be run as root."
  exit 1
fi

# Install minimal dependencies for the interactive setup wizard
apt-get update -qq
apt-get install -y -qq whiptail curl openssl unzip gpg > /dev/null

# Ensure script is executed from project root
if [ ! -d "./conf" ]; then
    echo "❌ Missing './conf' directory. Please run this script from the repository root."
    exit 1
fi

# -----------------------------------------------------------------------------
# 1. INTERACTIVE WIZARD
# -----------------------------------------------------------------------------
# Prompt for base domain name
DOMAIN=$(whiptail --inputbox "Enter your primary domain name (e.g., example.com):" 8 60 3>&1 1>&2 2>&3)
if [ -z "$DOMAIN" ]; then
    echo "❌ No domain provided. Aborting installation."
    exit 1
fi

# Webserver Choice (NGINX or Apache)
WEBSERVER=$(whiptail --title "Web Server Choice" --menu "Select the web server to configure:" 12 60 2 \
"NGINX" "Use NGINX reverse proxy configs" \
"APACHE" "Use Apache2 reverse proxy configs" 3>&1 1>&2 2>&3)

# Component Checklist
CHOICES=$(whiptail --title "AurionMail Installer" --checklist \
"Select the components to install on this machine:" 16 68 7 \
"LLDAP" "LLDAP Directory Server" ON \
"CORE" "Aurion Core (API + Ory Hydra + SSO + Bridges)" ON \
"STALWART" "Stalwart Mail Server" ON \
"BULWARK" "Bulwark Webmail" ON \
"CRYPTPAD" "CryptPad Collaboration Suite" ON 3>&1 1>&2 2>&3)

INSTALL_LLDAP=false
INSTALL_CORE=false
INSTALL_STALWART=false
INSTALL_BULWARK=false
INSTALL_CRYPTPAD=false

if [[ $CHOICES == *"LLDAP"* ]]; then INSTALL_LLDAP=true; fi
if [[ $CHOICES == *"CORE"* ]]; then INSTALL_CORE=true; fi
if [[ $CHOICES == *"STALWART"* ]]; then INSTALL_STALWART=true; fi
if [[ $CHOICES == *"BULWARK"* ]]; then INSTALL_BULWARK=true; fi
if [[ $CHOICES == *"CRYPTPAD"* ]]; then INSTALL_CRYPTPAD=true; fi

# -----------------------------------------------------------------------------
# 2. AUTOMATIC SECRET GENERATION
# -----------------------------------------------------------------------------
generate_secret() {
    openssl rand -base64 48 | tr -dc 'a-zA-Z0-9' | head -c 32
}

LDAP_JWT=$(generate_secret)
HYDRA_PASSWORD=$(generate_secret)
HYDRA_PAIRWISE_SALT=$(generate_secret)
HYDRA_SYSTEM_SECRET=$(generate_secret)
STALWART_ADMIN_PASSWORD=$(generate_secret)
SECRET_BULWARK_SSO=$(generate_secret)
SECRET_CRYPTPAD_SSO=$(generate_secret)
AURION_API_INTERNAL_SECRET=$(generate_secret)
AURION_JWT_SECRET=$(generate_secret)
AURION_DB_PASSWORD=$(generate_secret)

# Save generated secrets
SAVED_SECRETS_FILE="./installation_secrets.env"
cat <<EOF > "$SAVED_SECRETS_FILE"
# AurionMail Infrastructure Secrets
# KEEP THIS FILE SECURE!
DOMAIN="$DOMAIN"
LDAP_JWT="$LDAP_JWT"
HYDRA_PASSWORD="$HYDRA_PASSWORD"
HYDRA_PAIRWISE_SALT="$HYDRA_PAIRWISE_SALT"
HYDRA_SYSTEM_SECRET="$HYDRA_SYSTEM_SECRET"
STALWART_ADMIN_PASSWORD="$STALWART_ADMIN_PASSWORD"
SECRET_BULWARK_SSO="$SECRET_BULWARK_SSO"
SECRET_CRYPTPAD_SSO="$SECRET_CRYPTPAD_SSO"
AURION_API_INTERNAL_SECRET="$AURION_API_INTERNAL_SECRET"
AURION_JWT_SECRET="$AURION_JWT_SECRET"
AURION_DB_PASSWORD="$AURION_DB_PASSWORD"
EOF
chmod 600 "$SAVED_SECRETS_FILE"

echo "✅ Secrets generated and saved to $SAVED_SECRETS_FILE"

# -----------------------------------------------------------------------------
# 3. RECONFIGURE CONF TEMPLATES WITH REAL DOMAIN
# -----------------------------------------------------------------------------
echo "🔧 Replacing DOMAIN_REPLACE_ME in ./conf with $DOMAIN..."
find ./conf -type f -exec sed -i "s/DOMAIN_REPLACE_ME/$DOMAIN/g" {} +

# -----------------------------------------------------------------------------
# 4. SYSTEM USER CREATION
# -----------------------------------------------------------------------------
echo "👤 Provisioning system users..."
id -u aurion &>/dev/null || useradd -s /bin/false -m aurion
if [ "$INSTALL_BULWARK" = true ]; then
    id -u bulwark &>/dev/null || useradd -s /bin/false -m bulwark
fi
if [ "$INSTALL_CRYPTPAD" = true ]; then
    id -u pad &>/dev/null || useradd -s /bin/false -m pad
fi

# -----------------------------------------------------------------------------
# 5. LLDAP MODULE
# -----------------------------------------------------------------------------
if [ "$INSTALL_LLDAP" = true ]; then
    echo "📂 Installing LLDAP Directory Server..."
    echo 'deb http://download.opensuse.org/repositories/home:/Masgalor:/LLDAP/Debian_13/ /' | tee /etc/apt/sources.list.d/home:Masgalor:LLDAP.list
    curl -fsSL https://download.opensuse.org/repositories/home:Masgalor:LLDAP/Debian_13/Release.key | gpg --dearmor | tee /etc/apt/trusted.gpg.d/home_Masgalor_LLDAP.gpg > /dev/null
    apt-get update -qq && apt-get install -y -qq lldap lldap-extras

    DN_PARTS=$(echo "$DOMAIN" | awk -F. '{for(i=1;i<=NF;i++) print "dc=" $i}' | paste -sd, -)
    sed -i "s/jwt_secret = .*/jwt_secret = \"$LDAP_JWT\"/" /etc/lldap/lldap_config.toml
    sed -i "s/ldap_base_dn = .*/ldap_base_dn = \"$DN_PARTS\"/" /etc/lldap/lldap_config.toml
    systemctl restart lldap

    # Install Web Server Config
    if [ "$WEBSERVER" = "NGINX" ]; then
        cp ./conf/nginx/ldap.domain /etc/nginx/sites-available/ldap.$DOMAIN
    else
        cp ./conf/apache/ldap.conf /etc/apache2/sites-available/ldap.conf
    fi
fi

# -----------------------------------------------------------------------------
# 6. AURION CORE MODULE (Hydra + SSO + API + Bridges)
# -----------------------------------------------------------------------------
if [ "$INSTALL_CORE" = true ]; then
    echo "⚙️ Installing Aurion Core Stack..."

    # Fetch release
    sudo -u aurion bash -c "cd /home/aurion && wget -q https://github.com/AurionMail/docs/releases/download/0.0.2/aurionmail.zip && unzip -q -o aurionmail.zip"

    # Copy env files
    if [ -f "./conf/env/sso/.env" ]; then
        cp ./conf/env/sso/.env /home/aurion/aurionmail/sso/.env
    fi
    if [ -f "./conf/env/api/.env" ]; then
        cp ./conf/env/api/.env /home/aurion/aurionmail/api/.env
    fi

    # PostgreSQL Setup
    apt-get install -y -qq postgresql
    sudo -u postgres psql -c "CREATE USER hydra WITH PASSWORD '$HYDRA_PASSWORD';" || true
    sudo -u postgres psql -c "CREATE DATABASE hydra OWNER hydra;" || true
    sudo -u postgres psql -d hydra -c "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\"; GRANT ALL ON SCHEMA public TO hydra;" || true

    sudo -u postgres psql -c "CREATE USER aurionuser WITH PASSWORD '$AURION_DB_PASSWORD';" || true
    sudo -u postgres psql -c "CREATE DATABASE auriondb OWNER aurionuser;" || true
    sudo -u postgres psql -d auriondb -c "GRANT ALL ON SCHEMA public TO aurionuser;" || true

    # API Database Migrations
    cd /home/aurion/aurionmail/api/migrations
    PGPASSWORD="$AURION_DB_PASSWORD" psql -h localhost -U aurionuser -d auriondb -f init.sql
    chmod -R 750 /home/aurion/aurionmail/api/aurion-core
    chmod +x /home/aurion/aurionmail/api/aurion-api

    # Hydra Migrations
    cp ./conf/env/hydra/hydra.yml /home/aurion/aurionmail/hydra/config/hydra.yml
    /home/aurion/aurionmail/hydra/bin/hydra -c /home/aurion/aurionmail/hydra/config/hydra.yml migrate sql up --yes

    # Systemd Services
    cp ./conf/systemd/hydra.service /etc/systemd/system/
    cp ./conf/systemd/aurion-sso.service /etc/systemd/system/
    cp ./conf/systemd/aurion.service /etc/systemd/system/
    
    systemctl daemon-reload
    systemctl enable --now hydra aurion-sso aurion

    # Bridges Permissions
    cd /home/aurion/aurionmail/bridges
    find . -type f -name "*.html" -exec sed -i "s/DOMAIN_TO_REPLACE/$DOMAIN/g" {} +
    chmod 711 /home/aurion
    chmod 711 /home/aurion/aurionmail
    chmod -R 755 /home/aurion/aurionmail/bridges

    # Web Server Configs
    if [ "$WEBSERVER" = "NGINX" ]; then
        cp ./conf/nginx/oauth.domain /etc/nginx/sites-available/oauth.$DOMAIN
        cp ./conf/nginx/sso.domain /etc/nginx/sites-available/sso.$DOMAIN
        cp ./conf/nginx/api.domain /etc/nginx/sites-available/api.$DOMAIN
    else
        cp ./conf/apache/oauth.conf /etc/apache2/sites-available/oauth.conf
        cp ./conf/apache/sso.conf /etc/apache2/sites-available/sso.conf
        cp ./conf/apache/api.conf /etc/apache2/sites-available/api.conf
    fi
fi

# -----------------------------------------------------------------------------
# 7. CRYPTPAD MODULE
# -----------------------------------------------------------------------------
if [ "$INSTALL_CRYPTPAD" = true ]; then
    echo "📝 Installing CryptPad..."
    sudo -u pad bash -c "
        cd /home/pad
        wget -q https://github.com/AurionMail/docs/releases/download/0.0.2/cryptpad.zip
        unzip -q -o cryptpad.zip
        cd cryptpad
        find customize lib www -type f -exec sed -i 's/AURION_DOMAIN_REPLACE_ME/$DOMAIN/g' {} +
    "
    if [ -f "./conf/env/pad/sso.js" ]; then
        cp ./conf/env/pad/sso.js /home/pad/cryptpad/config/sso.js
    fi

    cp ./conf/systemd/cryptpad.service /etc/systemd/system/
    systemctl daemon-reload
    systemctl enable --now cryptpad

    if [ "$WEBSERVER" = "NGINX" ]; then
        cp ./conf/nginx/pad.domain /etc/nginx/sites-available/pad.$DOMAIN
    else
        cp ./conf/apache/pad.conf /etc/apache2/sites-available/pad.conf
    fi
fi

# -----------------------------------------------------------------------------
# 8. BULWARK MODULE
# -----------------------------------------------------------------------------
if [ "$INSTALL_BULWARK" = true ]; then
    echo "📬 Installing Bulwark Webmail..."
    sudo -u bulwark bash -c "
        cd /home/bulwark
        wget -q https://github.com/bulwarkmail/webmail/releases/download/1.7.8/bulwark-standalone-1.7.8-linux-amd64.tar.gz
        tar -xvf bulwark-standalone-1.7.8-linux-amd64.tar.gz > /dev/null
    "
    sudo find /home/bulwark/webmail/node_modules/next/dist/bin -type f -exec chmod 755 {} \; 2>/dev/null || true
    
    # Deploy .env.local
    if [ -f "./conf/env/bulwark/.env.local" ]; then
        cp ./conf/env/bulwark/.env.local /home/bulwark/webmail/.env.local
        chown bulwark:bulwark /home/bulwark/webmail/.env.local
    elif [ -f "./conf/env/bulwark/.env" ]; then
        cp ./conf/env/bulwark/.env /home/bulwark/webmail/.env.local
        chown bulwark:bulwark /home/bulwark/webmail/.env.local
    fi

    cp ./conf/systemd/bulwark-webmail.service /etc/systemd/system/
    systemctl daemon-reload
    systemctl enable --now bulwark-webmail

    if [ "$WEBSERVER" = "NGINX" ]; then
        cp ./conf/nginx/web.domain /etc/nginx/sites-available/web.$DOMAIN
    else
        cp ./conf/apache/web.conf /etc/apache2/sites-available/web.conf
    fi
fi

# -----------------------------------------------------------------------------
# 9. STALWART MODULE
# -----------------------------------------------------------------------------
if [ "$INSTALL_STALWART" = true ]; then
    echo "✉️ Installing Stalwart Mail Server..."
    curl --proto '=https' --tlsv1.2 -sSf https://stalw.art/install.sh | sh
    echo "STALWART_RECOVERY_ADMIN=admin:$STALWART_ADMIN_PASSWORD" >> /etc/stalwart/stalwart.env

    if [ "$WEBSERVER" = "NGINX" ]; then
        cp ./conf/nginx/mail.domain /etc/nginx/sites-available/mail.$DOMAIN
    else
        cp ./conf/apache/mail.conf /etc/apache2/sites-available/mail.conf
    fi
fi

# -----------------------------------------------------------------------------
# 10. OAUTH2 HYDRA CLIENT PROVISIONING
# -----------------------------------------------------------------------------
if [ "$INSTALL_CORE" = true ]; then
    echo "🔑 Configuring Hydra OAuth2 Clients..."
    
    if [ "$INSTALL_BULWARK" = true ]; then
        /home/aurion/aurionmail/hydra/bin/hydra create oauth2-client \
          --endpoint http://127.0.0.1:4445 \
          --id stalwart \
          --name "AurionMail Webmail" \
          --secret "$SECRET_BULWARK_SSO" \
          --access-token-strategy jwt \
          --audience "stalwart" \
          --grant-type authorization_code,refresh_token \
          --response-type code \
          --scope openid,profile,email,offline_access \
          --redirect-uri "https://web.$DOMAIN/auth/callback,https://web.$DOMAIN/en/auth/callback,https://web.$DOMAIN/fr/auth/callback" \
          --token-endpoint-auth-method client_secret_post \
          --skip-consent || true
    fi

    if [ "$INSTALL_CRYPTPAD" = true ]; then
        /home/aurion/aurionmail/hydra/bin/hydra create oauth2-client \
          --endpoint http://127.0.0.1:4445 \
          --id cryptpad \
          --name "CryptPad" \
          --secret "$SECRET_CRYPTPAD_SSO" \
          --access-token-strategy jwt \
          --grant-type authorization_code,refresh_token \
          --response-type code \
          --scope openid,profile,email,offline_access \
          --redirect-uri "https://pad.$DOMAIN/ssoauth" \
          --token-endpoint-auth-method client_secret_basic \
          --skip-consent || true
    fi
fi

# -----------------------------------------------------------------------------
# 11. FINAL SUMMARY
# -----------------------------------------------------------------------------
whiptail --title "Installation Complete" --msgbox \
"The setup process has completed successfully!\n\nAll webserver configs for $WEBSERVER have been copied into place.\nSecrets stored at: $SAVED_SECRETS_FILE" 12 70