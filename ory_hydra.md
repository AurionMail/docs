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
  consent: http://127.0.0.1:3000/consent
  login: http://127.0.0.1:3000/login
  logout: http://127.0.0.1:3000/logout
  device:
    verification: http://127.0.0.1:3000/device/verify
    success: http://127.0.0.1:3000/device/success

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

