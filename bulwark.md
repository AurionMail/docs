This conf file is used to pass secret to bulwark webmail. The details for configuration of SSO are un `ory_hydra.md`.

```
<IfModule mod_ssl.c>
<VirtualHost *:443>
    ServerName web.mail.aurionmail.org

    ProxyRequests Off
    ProxyPreserveHost On
    ProxyVia Full


    <Proxy *>
        Require all granted
    </Proxy>

    # AURION
    ProxyPass "/bridge-minimal.html" !

    # Routing rules for Next.js WebSockets (Server Actions / Subscriptions)
    RewriteEngine On
    RewriteCond %{HTTP:Upgrade} =websocket [NC]
    RewriteRule ^/(.*)           ws://127.0.0.1:3000/$1 [P,L]

    


    # Standard HTTP reverse proxy to the local Node.js instance
    ProxyPass / http://127.0.0.1:3000/
    ProxyPassReverse / http://127.0.0.1:3000/

    # Security headers for proxied sessions
    RequestHeader set X-Forwarded-Proto "https"
    RequestHeader set X-Forwarded-Port "443"

    # Additional standard hardening headers
    Header always set X-Content-Type-Options "nosniff"
    Header always set X-Frame-Options "SAMEORIGIN"

    ErrorLog ${APACHE_LOG_DIR}/bulwark-webmail-error.log
    CustomLog ${APACHE_LOG_DIR}/bulwark-webmail-access.log combined

    # AURION BRDIGE
    Alias "/bridge-minimal.html" "/var/www/bulwark-bridge/bridge-minimal.html"

  <Location "/bridge-minimal.html">
     Header always set Content-Security-Policy "frame-ancestors WEBMAIL_ORIGIN_WP"
     Require all granted
  </Location>

Include /etc/letsencrypt/options-ssl-apache.conf
SSLCertificateFile /etc/letsencrypt/live/officialweb.mail.aurionmail.org/fullchain.pem
SSLCertificateKeyFile /etc/letsencrypt/live/officialweb.mail.aurionmail.org/privkey.pem
</VirtualHost>
</IfModule>
```