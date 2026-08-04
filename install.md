# Aurion Installation Tutorial
This tutoriel covers the parts in which AurionMail is involved. This tutorial covers installation with Stalwart, Bulwark, lldap, ory hydra, cryptpad and all you need.
## Prerequies
You need a domain name. We assume this from this domain will send emails Add these subdomains to its DNS Zone :
- mail. : used by Stalwart
- web. : used by the webmail Bulwark
- oauth. used by Hydra Backend
- sso. : used by SSO Frontend
- pad. used by Cryptpad
- sand. used by Cryptpad
- ldap : used by lldap webAdmin UI
- api : used by Aurion Core API

For testing with up to 30 users, 2GB cheap VPS is enough. In this tutorial, we will to use
- debian 13
- apache2 (I know..., ngix and caddy come soon)
- certbot
- postgresql for the Aurion API DB
- nodeJS 22 LTS
## Cheatsheet

| Service |  Port Usage | Adress & Port | Domain | User | Update type | Path |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **LLDAP** |  UI | `127.0.0.1:17170` | `ldap.` | `lldap` | `AUTO (package manager)` | N/A |
| **LLDAP** | LDAP (Protocol) | `127.0.0.1:3890` | - | `lldap` | `AUTO (package manager)` | N/A |
| **Ory Hydra** | Authentification (Auth) | `127.0.0.1:4444` | `oauth.` | `aurion` | `MANUAL` |/home/aurion/aurionmail/hydra |
| **Ory Hydra** | Administration (Admin) | `127.0.0.1:4445` | - | `aurion` | `MANUAL` | /home/aurion/aurionmail/hydra|
| **SSO App** | Application SSO | `127.0.0.1:3030` | `sso.` | `aurion` | `MANUAL` |/home/aurion/aurionmail/sso |
| **Cryptpad** | Web App  | `127.0.0.1:3010` | `pad.` / `sand.` | `pad` | `MANUAL` |/home/pad/cryptpad/ |
| **Cryptpad** | WebSockets | `127.0.0.1:3013` | `pad.` / `sand.` | `pad` | `MANUAL` | /home/pad/cryptpad|
| **Bulwark Webmail** | Webmail UI | `127.0.0.1:3000` | `web.` | `user` | `MANUAL` |/home/bulwark/webmail |
| **Aurion API** | API | `127.0.0.1:8070` | `api.` | `aurion` | `MANUAL` | /home/aurion/aurionmail/api |
| **Stalwart** | Mail Server | `127.0.0.1:8080` | `mail.` | `stalwart` | `MANUAL` | /opt/stalwart |
| **Bridges** | Bridges | *Integrade with reverse proxy* | - | `aurion` | `MANUAL` |/home/aurion/aurionmail/bridges  |

## LDAP
- We use lldap from the [debian repo](https://software.opensuse.org//download.html?project=home%3AMasgalor%3ALLDAP&package=lldap)
- `sudo apt install lldap lldap-extras`
- edit conf file at `/etc/lldap/lldap_config.toml`
    - ldap_host = "127.0.0.1"
    - http_host = "127.0.0.1"
    - jwt_secret = "GENERATE"
    - ldap_base_dn = "dc=DOMAIN,dc=DOMAINEND" :  for refernece, with aurionmail.org, we would use dc=aurionmail,dc=org

- Add the apache conf file :
```
<VirtualHost *:80>
    ServerName ldap.DOMAIN.org

    ProxyPreserveHost On
    ProxyPass / http://127.0.0.1:17170/
    ProxyPassReverse / http://127.0.0.1:17170/

    RequestHeader set X-Forwarded-Proto "http"
    RequestHeader set X-Forwarded-Host "ldap.DOMAIN.org"

    ErrorLog ${APACHE_LOG_DIR}/lldap-admin_error.log
    CustomLog ${APACHE_LOG_DIR}/lldap-admin_access.log combined
</VirtualHost>
```
- of course, use certbot to enable https.
## Install Aurion
- useradd -s /bin/false -m aurion 
- sudo -u aurion bash
- get latest release zip : wget https://github.com/AurionMail/docs/releases/download/0.0.2/aurionmail.zip
- unzip aurionmail.zip

You have now installed the API, Hydra, the SSO app and the bridges. Now, let's configure these !
## Ory Hydra
- sudo -i -u postgres
- createdb hydra
- psql
- ALTER SYSTEM SET password_encryption = 'scram-sha-256';
- SELECT pg_reload_conf();
- CREATE USER hydra PASSWORD '<YOUR_PASSWORD_HERE>';
- nano /etc/postgresql/15/main/pg_hba.conf
- add host    all             all             127.0.0.1/32            scram-sha-256
- psql -U hydra -W -h 127.0.0.1 and type password

- sudo -i -u postgres psql -d hydra
- GRANT ALL ON SCHEMA public TO hydra;
- GRANT USAGE ON SCHEMA public TO hydra;
- ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO hydra;
- ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO hydra;
- CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
- GRANT EXECUTE ON FUNCTION uuid_generate_v4() TO hydra;
- \q

- nano /home/aurion/aurionmail/hydra/config/hydra.yml
- paste
```
serve:
  cookies:
    same_site_mode: Lax
dsn: postgres://hydra:<YOUR_PASSWORD_HERE>@127.0.0.1:5432/hydra?sslmode=disable&max_conns=20&max_idle_conns=4
urls:
  self:
    issuer: https://oauth.DOMAIN
  consent: https://sso.DOMAIN/consent
  login: https://sso.DOMAIN/login
  logout: https://sso.DOMAIN/logout
  post_logout_redirect: https://sso.DOMAIN/exited

  device:
    verification: https://sso.DOMAIN/device/verify
    success: https://sso.DOMAIN/device/success

secrets:
  system:
    - RandomThingsLikeBlablalalalala

oidc:
  subject_identifiers:
    supported_types:
      - pairwise
      - public
    pairwise:
      salt: RandomThingsLikeBlablalalalalalouzuzz
```
- apply migrations with /home/aurion/aurionmail/hydra/bin/hydra -c /home/aurion/aurionmail/hydra/config/hydra.yml migrate sql up

- nano /etc/systemd/system/hydra.service and paste
```
[Unit]
Description=Hydra Service
After=network.target
StartLimitIntervalSec=0

[Service]
Type=simple
Restart=always
RestartSec=1
User=aurion
Environment=SERVE_ADMIN_HOST=127.0.0.1
Environment=SERVE_PUBLIC_HOST=127.0.0.1
ExecStart=/home/aurion/aurionmail/hydra/bin/hydra -c /home/aurion/aurionmail/hydra/config/hydra.yml serve all

[Install]
WantedBy=multi-user.target
```
- systemctl enable hydra.service
- systemctl start hydra.service
- systemctl status hydra.service to check if all is OK

- sudo nano /etc/apache2/sites-available/hydra.conf and paste
```
<VirtualHost *:80>
    ServerName oauth.DOMAIN

    # Certbot
    DocumentRoot /var/www/html
    <Directory /var/www/html/.well-known/acme-challenge/>
        Options None
        AllowOverride None
        Require all granted
    </Directory>

    RewriteEngine On
    RewriteCond %{REQUEST_URI} !^/\.well-known/acme-challenge/
    RewriteRule ^/(.*)$ https://%{HTTP_HOST}/$1 [R=301,L]
</VirtualHost>

<VirtualHost *:443>
    ServerName oauth.DOMAIN

    SSLEngine on
    SSLCertificateFile /etc/letsencrypt/live/oauth.DOMAIN/fullchain.pem
    SSLCertificateKeyFile /etc/letsencrypt/live/oauth.DOMAIN/privkey.pem
    Include /etc/letsencrypt/options-ssl-apache.conf

    ProxyPreserveHost On
    RequestHeader set X-Real-IP "%{REMOTE_ADDR}s"
    RequestHeader set X-Forwarded-Proto "https"

    <LocationMatch "^/(.well-known|oauth2/auth|oauth2/token|oauth2/sessions|oauth2/revoke|oauth2/fallbacks/consent|oauth2/fallbacks/error|userinfo)(/.*)?$">
        Require all granted
        ProxyPass http://127.0.0.1:4444
        ProxyPassReverse http://127.0.0.1:4444
    </LocationMatch>

</VirtualHost>
```
- sudo certbot certonly --apache -d oauth.DOMAIN
- sudo a2ensite hydra.conf 
- sudo systemctl restart apache2

At this point, Hydra and LDAP are installed but they don't speak to them. It is normal, and they never do this. We need to install the SSO App
## SSO App
Ory Hydra only manage the OAuth and OIDC process. He doesn't have a fronted to let the user use its credentiald. It is for the reason we choose it by the way :)

We use this app to check credential against LDAP and let the user consent to give acces to the clients app its info
### Installation
- cd /home/aurion/aurionmail/sso
- cp .example.env .env
- sudo nano .env and add the .env with your values. You can also add them to your .service file (next line) but a .env must be present (even empty) :
```
PORT=3030
BASE_URL=https://sso.DOMAIN
HYDRA_ADMIN_URL=http://localhost:4445
# Only used in paid version of Ory Hydra
ORY_API_KEY=YOUR_API_KEY
LDAP_URL=ldap://127.0.0.1:3890
LDAP_USER_DN_PATTERN=uid={username},ou=people,dc=DOMAIN,dc=org
WEBMAIL_DOMAIN_WP=https://web.DOMAIN
CRYPTPAD_DOMAIN_WP=https://pad.DOMAIN
CORE_API_URL=https://api.DOMAIN
CORE_API_INTERNAL_SECRET=yourSecret
```
- sudo nano /etc/systemd/system/aurion-sso.service and add
```
[Unit]
Description=Aurion SSO
After=network.target

[Service]
Type=simple
User=aurion
WorkingDirectory=/home/aurion/aurionmail/sso
ExecStart=/usr/bin/npm run serve
Restart=always
RestartSec=5
[Install]
WantedBy=multi-user.target
```
- sudo systemctl daemon-reload
- sudo systemctl start aurion-sso.service
- sudo systemctl enable aurion-sso.service

-  sudo nano /etc/apache2/sites-available/sso.conf (used to let certbot do its works)
```
# --- Configuration HTTP (Port 80) ---
<VirtualHost *:80>
    ServerName sso.DOMAIN
    DocumentRoot /var/www/html
    <Directory /var/www/html/.well-known/acme-challenge/>
        Options None
        AllowOverride None
        Require all granted
    </Directory>
    RewriteEngine On
    RewriteCond %{REQUEST_URI} !^/\.well-known/acme-challenge/
    RewriteRule ^ https://%{SERVER_NAME}%{REQUEST_URI} [R=301,L]

    ErrorLog ${APACHE_LOG_DIR}/mon-domaine-error.log
    CustomLog ${APACHE_LOG_DIR}/mon-domaine-access.log combined
</VirtualHost>
```
- sudo a2ensite sso.conf
- sudo systemctl reload apache2
- sudo certbot --apache
- sudo nano /etc/apache2/sites-available/sso-le-ssl.conf and add reverse proxy

```                               
<IfModule mod_ssl.c>
<VirtualHost *:443>
    ServerName sso.DOMAIN
    DocumentRoot /var/www/html

    <Directory /var/www/html/.well-known/acme-challenge/>
        Options None
        AllowOverride None
        Require all granted
    </Directory>

    RewriteEngine On

    ProxyPreserveHost On
    ProxyPass / http://127.0.0.1:3030/
    ProxyPassReverse / http://127.0.0.1:3030/

    RequestHeader set X-Forwarded-Proto "https"
    RequestHeader set X-Forwarded-Port "443"

    ErrorLog ${APACHE_LOG_DIR}/mon-domaine-error.log
    CustomLog ${APACHE_LOG_DIR}/mon-domaine-access.log combined

SSLCertificateFile /etc/letsencrypt/live/sso.DOMAIN/fullchain.pem
SSLCertificateKeyFile /etc/letsencrypt/live/sso.DOMAIN/privkey.pem
Include /etc/letsencrypt/options-ssl-apache.conf
</VirtualHost>
</IfModule>
```
## Cryptpad
- useradd -s /bin/false -m pad
- wget https://github.com/AurionMail/docs/releases/download/0.0.2/cryptpad.zip 
- unzip cryptpad.zip 
- cd cryptpad/config
- cp config.example.js config.js
- cp sso.example.js sso.js
- follow instrcutons at https://docs.cryptpad.org/en/admin_guide/installation.html from "configuration" or "onlyoffice" if you want.
- nano config.js and edit this values :
    - httpUnsafeOrigin: 'https://pad.DOMAIN',
    - httpSafeOrigin: "https://sand.DOMAIN",
    - httpPort: 3010,
    - httpSafePort: 3011,
    - websocketPort: 3013,
    - installMethod: 'aurion',
- nano /etc/apache2/sites-available/pad.conf
```
# SPDX-FileCopyrightText: 2023 XWiki CryptPad Team <contact@cryptpad.org> and contributors
#
# SPDX-License-Identifier: AGPL-3.0-or-later

#   This file is included strictly as an example of how Apache httpd can be
#   configured to work with CryptPad. If you are using CryptPad in production
#   and require professional support please contact sales@cryptpad.org

#   This configuration requires mod_ssl, mod_socache_shmcb, mod_proxy,
#   mod_proxy_http and mod_headers

#Listen 443

SSLCipherSuite ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384
SSLProxyCipherSuite ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384
SSLHonorCipherOrder off
SSLProtocol all -SSLv3 -TLSv1 -TLSv1.1
SSLProxyProtocol all -SSLv3 -TLSv1 -TLSv1.1
SSLSessionCache "shmcb:${APACHE_RUN_DIR}/ssl_scache(512000)"
SSLSessionCacheTimeout 86400
SSLSessionTickets off
SSLUseStapling on
SSLStaplingCache "shmcb:${APACHE_RUN_DIR}/ssl_stapling(32768)"

<VirtualHost *:443>
  ServerName pad.DOMAIN
  ServerAlias sand.DOMAIN
  Header always set Strict-Transport-Security "max-age=63072000; includeSubDomains"


 SSLEngine on
  SSLCertificateFile /etc/letsencrypt/live/DOMAIN/cert.pem
  SSLCertificateKeyFile /etc/letsencrypt/live/DOMAIN/privkey.pem
   
  BrowserMatch "MSIE [2-5]" \
        nokeepalive ssl-unclean-shutdown \
        downgrade-1.0 force-response-1.0
   
  Protocols h2 http/1.1
  AddType application/javascript mjs

  # =============================================================
  # AURION PROXY RULES
  # =============================================================
  RewriteEngine On

  RewriteCond %{REQUEST_URI} ^/login$
  RewriteCond %{QUERY_STRING} !(^|&)from=aurion(&|$) [NC]
  RewriteRule ^ https://web.DOMAIN [R=302,L]

  ProxyPass "/bridge-minimal.html" !
  ProxyPass "/bridge-sand.html" !

  ProxyPass "/cryptpad_websocket" "http://localhost:3013/" upgrade=websocket
  ProxyPassReverse "/cryptpad_websocket" "http://localhost:3013/"

  ProxyPass "/" "http://localhost:3010/" upgrade=websocket
  ProxyPassReverse "/" "http://localhost:3010/"

  Alias "/bridge-minimal.html" "/home/aurion/aurionmail/bridges/bridge-minimal.html"

  <Location "/bridge-minimal.html">
     Header always set Content-Security-Policy "frame-ancestors https://web.DOMAIN https://sso.DOMAIN"
     Require all granted
  </Location>

 Alias "/bridge-sand.html" "/home/aurion/aurionmail/bridges/bridge-sand.html"

  <Location "/bridge-sand.html">
     Header always set Content-Security-Policy "frame-ancestors https://pad.DOMAIN https://web.DOMAIN https://sso.DOMAIN"
     Require all granted
  </Location>

  LimitRequestBody 157286400

</VirtualHost>

```
- nano /home/pad/cryptpad/config/sso.js
```
// SPDX-FileCopyrightText: 2023 XWiki CryptPad Team <contact@cryptpad.org> and contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

//const fs = require('node:fs');
module.exports = {
    enabled: true,
    enforced: true,
    cpPassword: true,
    forceCpPassword: true,
    list: [
   {
        name: 'Aurion SSO',
        type: 'oidc',
        url: 'https://oauth.DOMAIN',
        client_id: 'cryptpad',
        client_secret: 'SECRET_CRYPTPAD_SSO',
        jwt_alg: 'RS256',
        userinfo: false,
        username_claim: 'sub'
}
    ]
};
```
## Stalwart Web Server
### Installation
Run the  at [Installlation Script](https://stalw.art/docs/install/platform/linux/) provided by Stalwart and config it as usually.
Warning : We will soon enable the OIDC provider in stalwart. As a result, we won't be able to connect to admin account in admin webUI. So, you need to add the env variable STALWART_RECOVERY_ADMIN=admin:cool_password.

now, apache conf file: 
```
<VirtualHost *:80>
    ServerName mail.DOMAIN

    # Configuration des en-têtes pour le reverse proxy
    ProxyPreserveHost On
    ProxyRequests Off

    RequestHeader set X-Real-IP %{REMOTE_ADDR}s
    RequestHeader set X-Forwarded-For %{REMOTE_ADDR}s
    RequestHeader set X-Forwarded-Proto "http"

    RewriteEngine On
    RewriteCond %{HTTP:Upgrade} websocket [NC]
    RewriteCond %{HTTP:Connection} upgrade [NC]
    RewriteRule ^/?(.*) ws://127.0.0.1:8080/$1 [P,L]

    ProxyPass / http://127.0.0.1:8080/
    ProxyPassReverse / http://127.0.0.1:8080/

    ErrorLog ${APACHE_LOG_DIR}/stalwart_error.log
    CustomLog ${APACHE_LOG_DIR}/stalwart_access.log combined
</VirtualHost>
```
- run certbot.

## Bulwark Webmail

- sudo useradd -r -m -d /home/bulwark -s /bin/bash bulwark
- sudo mkdir -p /home/bulwark/webmail/data/{settings,admin,admin-state}
- wget https://github.com/bulwarkmail/webmail/releases/latest/download/bulwark-webmail.tar.gz -O /tmp/bulwark-webmail.tar.gz
- sudo tar -xzf /tmp/bulwark-webmail.tar.gz -C /home/bulwark/webmail
- rm -f /tmp/bulwark-webmail.tar.gz
- cd /home/bulwark/webmail
- sudo -u bulwark npm install --omit=dev --no-audit --ignore-scripts --no-fund
- sudo chown -R bulwark:bulwark /home/bulwark/webmail
- sudo find /home/bulwark/webmail -type d -exec chmod 755 {} \;
- sudo find /home/bulwark/webmail -type f -exec chmod 644 {} \;
- 
```
sudo chmod -R 755 /home/bulwark/webmail/node_modules/.bin
sudo find /home/bulwark/webmail/node_modules/next/dist/bin -type f -exec chmod 755 {} \; 2>/dev/null || true
```
- sudo nano `/etc/systemd/system/bulwark-webmail.service` :

```ini
[Unit]
Description=Bulwark Webmail Service
After=network.target

[Service]
Type=simple
User=bulwark
Group=bulwark
WorkingDirectory=/home/bulwark/webmail
ExecStart=/usr/bin/npm start
Restart=always
RestartSec=10
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=bulwark-webmail
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target

```
```bash
sudo systemctl daemon-reload
sudo systemctl enable --now bulwark-webmail

```

- sudo nano `/etc/apache2/sites-available/bulwark-webmail.conf` :

```apache
<VirtualHost *:80>
    ServerName web.DOMAIN

    ProxyRequests Off
    ProxyPreserveHost On
    ProxyVia Full

    <Proxy *>
        Require all granted
    </Proxy>

    ProxyPass "/bridge-minimal.html" !

    # Routing WebSockets (Next.js)
    RewriteEngine On
    RewriteCond %{HTTP:Upgrade} =websocket [NC]
    RewriteRule ^/(.*)           ws://127.0.0.1:3000/$1 [P,L]

    ProxyPass / http://127.0.0.1:3000/
    ProxyPassReverse / http://127.0.0.1:3000/

    RequestHeader set X-Forwarded-Proto "http"
    RequestHeader set X-Forwarded-Port "80"
    Header always set X-Content-Type-Options "nosniff"
    Header always set X-Frame-Options "SAMEORIGIN"

    Alias "/bridge-minimal.html" "/home/aurion/aurionmail/bridges/bridge-minimal.html"

    <Location "/bridge-minimal.html">
        Header always set Content-Security-Policy "frame-ancestors https://sso.DOMAIN"
        Require all granted
    </Location>

    ErrorLog ${APACHE_LOG_DIR}/bulwark-webmail-error.log
    CustomLog ${APACHE_LOG_DIR}/bulwark-webmail-access.log combined
</VirtualHost>

```
- activate https :
```bash
sudo a2ensite bulwark-webmail.conf
sudo systemctl restart apache2
sudo certbot --apache -d web.DOMAIN
```

## Aurion API
- cd /home/aurion/aurionmail/api
- sudo nano .env
- sudo -u postgres psql
- CREATE USER aurionUSER WITH PASSWORD 'pass';
- CREATE DATABASE aurionDB OWNER aurionUSER;
- \c aurionDB
- GRANT ALL ON SCHEMA public TO aurionUSER;
- ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO aurionUSER;
- ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO aurionUSER;
- exit
- sudo wget https://raw.githubusercontent.com/AurionMail/core-api/refs/heads/main/migrations/init.sql
- psql -h localhost -U aurionUSER -d aurionDB -f migrations/init.sql
- sudo chmod -R 750 ./aurion-core
- sudo chmod +x ./aurion-api
- Create the file /etc/systemd/system/aurion.service:
```
[Unit]
Description=Aurion Core Server
After=network.target postgresql.service

[Service]
Type=simple
User=aurion
WorkingDirectory=/home/aurion/aurionmail/api
ExecStart=/home/aurion/aurionmail/api/aurion-api
Restart=always
RestartSec=5
EnvironmentFile=/home/aurion/aurionmail/api/.env

[Install]
WantedBy=multi-user.target

Enable and start the service:

sudo systemctl daemon-reload
sudo systemctl enable aurion
sudo systemctl start aurion
```
- Add apache conf
```
<VirtualHost *:80>
    ServerName api.DOMAIN

    ProxyPreserveHost On
    ProxyPass / http://localhost:8070/
    ProxyPassReverse / http://localhost:8070/

    Header always set X-Content-Type-Options "nosniff"
    Header always set X-Frame-Options "DENY"
    Header always set X-XSS-Protection "1; mode=block"

    ErrorLog ${APACHE_LOG_DIR}/aurion-error.log
    CustomLog ${APACHE_LOG_DIR}/aurion-access.log combined
</VirtualHost>
```
- then enable cerbot
# Configure Auth

### Config for clients
#### Bulwark + Stalwart
```bash
  sudo ./hydra create client \  
  --endpoint http://127.0.0.1:4445 \  --id stalwart \
  --name "AurionMail Webmail"  \
  --secret "SECRET_BULWARK_SSO" \
  --access-token-strategy jwt  \
  --audience "stalwart" \ 
  --grant-type authorization_code,refresh_token  \
  --response-type code  \
  --scope openid,profile,email,offline_access  \
  --redirect-uri "https://web.DOMAIN/auth/callback,https://web.DOMAIN/en/auth/callback,https://web.DOMAIN/fr/auth/callback" \
  --token-endpoint-auth-method client_secret_post \
  --skip-consent
```

### Cryptpad
```bash
sudo ./hydra create client \
  --endpoint http://127.0.0.1:4445 \
  --id cryptpad \
  --name "CryptPad" \
  --secret "SECRET_CRYPTPAD_SSO" \
  --access-token-strategy jwt \
  --grant-type authorization_code,refresh_token \
  --response-type code \
  --scope openid,profile,email,offline_access \
  --redirect-uri "https://pad.DOMAIN/ssoauth" \
  --token-endpoint-auth-method client_secret_basic \
  --skip-consent
```
 ### Conf Bulwark
Go to admin ui : https://web.DOMAIN/admin then Authentication :
- Oauth : Activated
- OAuth Only : Activated
- OAuthClientID: stalwart 
- OAuth Client Secret : SECRET_BULWARK_SSO 
- OAuth Issuer URL : https://oauth.DOMAIN
- Auto SSO : Activated

### Conf Stalwart

Navigate to webUI with your admin account, then : Authentication->Directories 
- Issuer URL : https://oauth.DOMAIN
- Required Audience : null
- Required Scopes : null
- Username Claim : email
- Name Claim : name 
- Groups Claim : groups