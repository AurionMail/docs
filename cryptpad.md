## Cryptpad
To use cryptpad with Aurion, you can use this apache conf file. The details for configuring the SSO are in `ory_hydra.md`. This custom conf file enable to serve the minimal bridge in iframe to pass secrets to cryptpad.

```
# SPDX-FileCopyrightText: 2023 XWiki CryptPad Team <contact@cryptpad.org> and contributors
#
# SPDX-License-Identifier: AGPL-3.0-or-later

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
  ServerName pad.aurionmail.org
  ServerAlias sand.aurionmail.org
  Header always set Strict-Transport-Security "max-age=63072000; includeSubDomains"
   
  SSLEngine on
  SSLCertificateFile /etc/letsencrypt/live/aurionmail.org/cert.pem
  SSLCertificateKeyFile /etc/letsencrypt/live/aurionmail.org/privkey.pem
   
  BrowserMatch "MSIE [2-5]" \
        nokeepalive ssl-unclean-shutdown \
        downgrade-1.0 force-response-1.0
   
  Protocols h2 http/1.1
  AddType application/javascript mjs

  # =============================================================
  # ORDERED PROXY RULES
  # =============================================================
  
  # AURION BRIDGE
  ProxyPass "/bridge-minimal.html" !

  ProxyPass "/cryptpad_websocket" "http://localhost:3013/" upgrade=websocket
  ProxyPassReverse "/cryptpad_websocket" "http://localhost:3013/"

  ProxyPass "/" "http://localhost:3010/" upgrade=websocket
  ProxyPassReverse "/" "http://localhost:3010/"



  # AURION BRDIGE
  Alias "/bridge-minimal.html" "/var/www/cryptpad-bridge/bridge-minimal.html"

  <Location "/bridge-minimal.html">
     Header always set Content-Security-Policy "frame-ancestors WEBMAIL_ORIGIN_WP"
     Require all granted
  </Location>

  LimitRequestBody 157286400

</VirtualHost>
```