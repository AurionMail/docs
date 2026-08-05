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

- useradd -s /bin/false -m -d /opt/hydra hydra
- mkdir /opt/hydra/{bin,config}
- cd /opt/hydra/bin
- wget https://github.com/ory/hydra/releases/download/v26.2.0/hydra_26.2.0-linux_64bit.tar.gz
- tar xfvz hydra_26.2.0-linux_64bit.tar.gz
- rm *md
- rm LICENSE
- cd ../config
- nano hydra.yml
- paste
```
serve:
  cookies:
    same_site_mode: Lax
dsn: postgres://hydra:<YOUR_PASSWORD_HERE>@127.0.0.1:5432/hydra?sslmode=disable&max_conns=20&max_idle_conns=4
urls:
  self:
    issuer: https://oauth.domain.org
  consent: https://sso.aurionmail.org/consent
  login: https://sso.aurionmail.org/login
  logout: https://sso.aurionmail.org/logout
  device:
    verification: https://sso.aurionmail.org/device/verify
    success: https://sso.aurionmail.org/device/success

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
- apply migrations with /opt/hydra/bin/hydra -c /opt/hydra/config/hydra.yml migrate sql up

- chown -R hydra /opt/hydra/
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
User=hydra
Environment=SERVE_ADMIN_HOST=127.0.0.1
Environment=SERVE_PUBLIC_HOST=127.0.0.1
ExecStart=/opt/hydra/bin/hydra -c /opt/hydra/config/hydra.yml serve all

[Install]
WantedBy=multi-user.target
```
- systemctl enable hydra.service
- systemctl start hydra.service
- systemctl status hydra.service to check if all is OK

For this part, we used Apache, but you can use Ngink insetad, it os advised but not covered by this tuto
- sudo nano /etc/apache2/sites-available/hydra.conf and paste
```
<VirtualHost *:80>
    ServerName oauth.aurionmail.org

    # Autoriser le dossier d'authentification pour Certbot
    DocumentRoot /var/www/html
    <Directory /var/www/html/.well-known/acme-challenge/>
        Options None
        AllowOverride None
        Require all granted
    </Directory>

    # Redirection automatique vers HTTPS pour tout le reste
    RewriteEngine On
    RewriteCond %{REQUEST_URI} !^/\.well-known/acme-challenge/
    RewriteRule ^/(.*)$ https://%{HTTP_HOST}/$1 [R=301,L]
</VirtualHost>

<VirtualHost *:443>
    ServerName oauth.aurionmail.org

    # Configuration SSL (Certbot)
    SSLEngine on
    SSLCertificateFile /etc/letsencrypt/live/oauth.aurionmail.org/fullchain.pem
    SSLCertificateKeyFile /etc/letsencrypt/live/oauth.aurionmail.org/privkey.pem
    Include /etc/letsencrypt/options-ssl-apache.conf

    # Configuration des en-têtes Proxy
    ProxyPreserveHost On
    RequestHeader set X-Real-IP "%{REMOTE_ADDR}s"
    RequestHeader set X-Forwarded-Proto "https"

    # ------------------------------------------------------------------
    # Routes ADMIN (Port 4445) 
    # ------------------------------------------------------------------
    <LocationMatch "^/(admin|clients|keys|health|metrics|version|oauth2/auth/requests|oauth2/introspect|oauth2/flush)(/.*)?$">
        # Condition : IP dans 172.28.0.* OU paramètre ?secret=CHANGE-ME-INSECURE-PASSWORD
        <If "%{REMOTE_ADDR} =~ /^172\.28\.0\./ || %{QUERY_STRING} =~ /(^|&)secret=CHANGE-ME-INSECURE-PASSWORD($|&)/">
            Require all granted
        </If>
        <Else>
            Require all denied
        </Else>

        ProxyPass http://127.0.0.1:4445
        ProxyPassReverse http://127.0.0.1:4445
    </LocationMatch>

    # ------------------------------------------------------------------
    # Routes PUBLIC
    # ------------------------------------------------------------------
    <LocationMatch "^/(.well-known|oauth2/auth|oauth2/token|oauth2/sessions|oauth2/revoke|oauth2/fallbacks/consent|oauth2/fallbacks/error|userinfo)(/.*)?$">
        Require all granted
        ProxyPass http://127.0.0.1:4444
        ProxyPassReverse http://127.0.0.1:4444
    </LocationMatch>

</VirtualHost>
```
- sudo certbot certonly --apache -d oauth.aurionmail.org
- sudo a2ensite hydra.conf 
- sudo systemctl restart apache2

### Config for clients
#### Bulwark + Stalwart

  sudo ./hydra create client   --endpoint http://127.0.0.1:4445   --id stalwart   --name "AurionMail Webmail"   --secret "hdd514sdduiuriuge"   --access-token-strategy jwt   --audience "stalwart"   --grant-type authorization_code,refresh_token   --response-type code   --scope openid,profile,email,offline_access   --redirect-uri "https://officialweb.mail.aurionmail.org/auth/callback,https://officialweb.mail.aurionmail.org/en/auth/callback,https://officialweb.mail.aurionmail.org/fr/auth/callback"   --token-endpoint-auth-method client_secret_post   --skip-consent

### Cryptpad
sudo ./hydra create client \
  --endpoint http://127.0.0.1:4445 \
  --id cryptpad \
  --name "CryptPad" \
  --secret "ds47sd82diffug2034sfqvcuezmsdgve5" \
  --access-token-strategy jwt \
  --grant-type authorization_code,refresh_token \
  --response-type code \
  --scope openid,profile,email,offline_access \
  --redirect-uri "https://pad.aurionmail.org/ssoauth" \
  --token-endpoint-auth-method client_secret_basic \
  --skip-consent

 ### Conf Bulwark

Oauth : Y 
OAuth Only : Y
OAuthClientID: stalwart 
OAuth Client Secret : secret 
OAuth Issuer URL : https://auth.aurionmail.org
Auto SSO : Y 

### Conf Stalwart

Authentication->Directories 

Issuer URL : https://oauth.aurionmail.org
Required Audience : null
Required Scopes : null
Username Claim : email
Name Claim : name 
Groups Claim : groups

### Conf Cryptpad 

```javascript
// SPDX-FileCopyrightText: 2023 XWiki CryptPad Team <contact@cryptpad.org> and contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

//const fs = require('node:fs');
module.exports = {
    // Enable SSO login on this instance
    enabled: true,
    // Block registration for non-SSO users on this instance
    enforced: true,
    // Allow users to add an additional CryptPad password to their SSO account
    cpPassword: true,
    // You can also force your SSO users to add a CryptPad password
    forceCpPassword: true,
    // List of SSO providers
    list: [
    {
        name: 'hydra',
        type: 'oidc',
        url: 'https://oauth.aurionmail.org',
        client_id: 'cryptpad',
        client_secret: 'secret',
        jwt_alg: 'RS256',
        userinfo: false,
        username_claim: 'sub'

}
    ]
};
```