## SSO Fronted
Ory Hydra only manage the OAuth and OIDC process. He doesn't have a fronted to let the user use its credentiald. It is for the reason we choose it by the way :)

We use this app to check credential against LDAP and let the user consent to give acces to the clients app its info
### Installation
- cd /opt
- sudo git clone https://github.com/paulhenry46/hydra-login-consent-node
- cd  hydra-login-consent-node
- sudo npm install
- sudo cp .example.env .env
- sudo npm run build
- sudo npm run build:css
- sudo chown -R hydra:hydra /opt/hydra-login-consent-node/
- sudo nano /etc/systemd/system/hydra-login-consent.service and add
```
[Unit]
Description=Ory Hydra Login and Consent Node App
After=network.target

[Service]
Type=simple
User=hydra
WorkingDirectory=/opt/hydra-login-consent-node
ExecStart=/usr/bin/npm run serve
Restart=always
RestartSec=5
Environment=PORT=3030
Environment=HYDRA_ADMIN_URL=http://localhost:4445
Environment=BASE_URL=https://sso.aurionmail.org
Environemtn=LDAP_URL=ldap://127.0.0.1:3890
Environment=LDAP_USER_DN_PATTERN=uid={username},ou=people,dc=aurionmail,dc=org
[Install]
WantedBy=multi-user.target
```
- sudo systemctl daemon-reload
- sudo systemctl start hydra-login-consent.service
- sudo systemctl enable hydra-login-consent.service

-  sudo nano /etc/apache2/sites-available/sso.conf
```
# --- Configuration HTTP (Port 80) ---
<VirtualHost *:80>
    ServerName sso.aurionmail.org

    # Dossier web racine requis pour le défi HTTP-01 de Certbot
    DocumentRoot /var/www/html

    # Autorisation spécifique pour le dossier d'authentification Certbot
    <Directory /var/www/html/.well-known/acme-challenge/>
        Options None
        AllowOverride None
        Require all granted
    </Directory>

    # Redirection automatique vers HTTPS (sauf pour Certbot)
    RewriteEngine On
    RewriteCond %{REQUEST_URI} !^/\.well-known/acme-challenge/
    RewriteRule ^ https://%{SERVER_NAME}%{REQUEST_URI} [R=301,L]

    ErrorLog ${APACHE_LOG_DIR}/mon-domaine-error.log
    CustomLog ${APACHE_LOG_DIR}/mon-domaine-access.log combined
RewriteCond %{SERVER_NAME} =sso.aurionmail.org
RewriteRule ^ https://%{SERVER_NAME}%{REQUEST_URI} [END,NE,R=permanent]
</VirtualHost>
```
- sudo a2ensite sso.conf
- sudo systemctl reload apache2
- sudo certbot --apache
- sudo nano /etc/apache2/sites-available/sso-le-ssl.conf and add reberse proxy

```                               
<IfModule mod_ssl.c>
<VirtualHost *:443>
    ServerName sso.aurionmail.org

    # Dossier web racine requis pour le défi HTTP-01 de Certbot
    DocumentRoot /var/www/html

    # Autorisation spécifique pour le dossier d'authentification Certbot
    <Directory /var/www/html/.well-known/acme-challenge/>
        Options None
        AllowOverride None
        Require all granted
    </Directory>

    # Redirection automatique vers HTTPS (sauf pour Certbot)
    RewriteEngine On
# Some rewrite rules in this file were disabled on your HTTPS site,
# because they have the potential to create redirection loops.

#     RewriteCond %{REQUEST_URI} !^/\.well-known/acme-challenge/
#     RewriteRule ^ https://%{SERVER_NAME}%{REQUEST_URI} [R=301,L]
# Transmission des en-têtes HTTP d'origine au service arrière
    ProxyPreserveHost On
    ProxyPass / http://127.0.0.1:3030/
    ProxyPassReverse / http://127.0.0.1:3030/

    # Optionnel : En-têtes pour sécuriser et transmettre l'IP réelle du client
    RequestHeader set X-Forwarded-Proto "https"
    RequestHeader set X-Forwarded-Port "443"

    ErrorLog ${APACHE_LOG_DIR}/mon-domaine-error.log
    CustomLog ${APACHE_LOG_DIR}/mon-domaine-access.log combined

SSLCertificateFile /etc/letsencrypt/live/sso.aurionmail.org/fullchain.pem
SSLCertificateKeyFile /etc/letsencrypt/live/sso.aurionmail.org/privkey.pem
Include /etc/letsencrypt/options-ssl-apache.conf
</VirtualHost>
</IfModule>
```