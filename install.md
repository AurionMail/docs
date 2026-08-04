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
- LLDAP UI: 127.0.0.1:17170 -> ldap.
- LDAP: 127.0.0.1:3890
- Ory Hydra Auth : 127.0.0.1:4444 -> oauth.
- Ory Hydra Admin : 127.0.0.1:4445 -> oauth. (will be removed in future)
- SSO App : 127.0.0.1:3030 -> sso.
- Cryptpad : 127.0.0.1:3010 -> pad. / sand.
- Cryptpad: 127.0.0.1:3013 -> pad. / sand.
- Bulwark : 127.0.0.1:3000 -> web.
- Aurion API : 127.0.0.1:8070 -> api.

## LDAP
- We use lldap from the [debian repo](https://software.opensuse.org//download.html?project=home%3AMasgalor%3ALLDAP&package=lldap)
- `sudo apt install lldap lldap-extras`
- edit conf file at `/etc/lldap/lldap_config.toml`

```
## Tune the logging to be more verbose by setting this to be true.
## You can set it with the LLDAP_VERBOSE environment variable.
# verbose=false

## The host address that the LDAP server will be bound to.
## To enable IPv6 support, simply switch "ldap_host" to "::":
## To only allow connections from localhost (if you want to restrict to local self-hosted services),
## change it to "127.0.0.1" ("::1" in case of IPv6)".
ldap_host = "127.0.0.1"

## The port on which to have the LDAP server.
#ldap_port = 3890

## The host address that the HTTP server will be bound to.
## To enable IPv6 support, simply switch "http_host" to "::".
## To only allow connections from localhost (if you want to restrict to local self-hosted services),
## change it to "127.0.0.1" ("::1" in case of IPv6)".
http_host = "127.0.0.1"

## The port on which to have the HTTP server, for user login and
## administration.
#http_port = 17170

## The public URL of the server, for password reset links.
#http_url = "http://localhost"

## Random secret for JWT signature.
## This secret should be random, and should be shared with application
## servers that need to consume the JWTs.
## Changing this secret will invalidate all user sessions and require
## them to re-login.
## You should probably set it through the LLDAP_JWT_SECRET environment
## variable from a secret ".env" file.
## This can also be set from a file's contents by specifying the file path
## in the LLDAP_JWT_SECRET_FILE environment variable
## You can generate it with (on linux):
## LC_ALL=C tr -dc 'A-Za-z0-9!#%&'\''()*+,-./:;<=>?@[\]^_{|}~' </dev/urandom | head -c 32; echo ''
jwt_secret =

## Base DN for LDAP.
## This is usually your domain name, and is used as a
## namespace for your users. The choice is arbitrary, but will be needed
## to configure the LDAP integration with other services.
## The sample value is for "example.com", but you can extend it with as
## many "dc" as you want, and you don't actually need to own the domain
## name.
ldap_base_dn = "dc=yourDomain,dc=org"

## Admin username.
## For the LDAP interface, a value of "admin" here will create the LDAP
## user "cn=admin,ou=people,dc=example,dc=com" (with the base DN above).
## For the administration interface, this is the username.
#ldap_user_dn = "admin"

## Admin email.
## Email for the admin account. It is only used when initially creating
## the admin user, and can safely be omitted.
#ldap_user_email = "admin@example.com"

## Admin password.
## Password for the admin account, both for the LDAP bind and for the
## administration interface. It is only used when initially creating
## the admin user.
## It should be minimum 8 characters long.
## You can set it with the LLDAP_LDAP_USER_PASS environment variable.
## This can also be set from a file's contents by specifying the file path
## in the LLDAP_LDAP_USER_PASS_FILE environment variable
## Note: you can create another admin user for user administration, this
## is just the default one.
ldap_user_pass = "password"

## Force reset of the admin password.
## Break glass in case of emergency: if you lost the admin password, you
## can set this to true to force a reset of the admin password to the value
## of ldap_user_pass above.
## Alternatively, you can set it to "always" to reset every time the server starts.
# force_ldap_user_pass_reset = false

## Database URL.
## This encodes the type of database (SQlite, MySQL, or PostgreSQL)
## , the path, the user, password, and sometimes the mode (when
## relevant).
## Note: SQlite should come with "?mode=rwc" to create the DB
## if not present.
## Example URLs:
##  - "postgres://postgres-user:password@postgres-server/my-database"
##  - "mysql://mysql-user:password@mysql-server/my-database"
##
## This can be overridden with the LLDAP_DATABASE_URL env variable.
database_url = "sqlite:///var/lib/lldap/users.db?mode=rwc"

## Private key file.
## Not recommended, use key_seed instead.
## Contains the secret private key used to store the passwords safely.
## Note that even with a database dump and the private key, an attacker
## would still have to perform an (expensive) brute force attack to find
## each password.
## Randomly generated on first run if it doesn't exist.
## Env variable: LLDAP_KEY_FILE
#key_file = "/var/lib/lldap/private_key"

## Seed to generate the server private key, see key_file above.
## This can be any random string, the recommendation is that it's at least 12
## characters long.
## Env variable: LLDAP_KEY_SEED
key_seed = "Generate Random String"

## Ignored attributes.
## Some services will request attributes that are not present in LLDAP. When it
## is the case, LLDAP will warn about the attribute being unknown. If you want
## to ignore the attribute and the service works without, you can add it to this
## list to silence the warning.
#ignored_user_attributes = [ "sAMAccountName" ]
#ignored_group_attributes = [ "mail", "userPrincipalName" ]

## Options to configure SMTP parameters, to send password reset emails.
## To set these options from environment variables, use the following format
## (example with "password"): LLDAP_SMTP_OPTIONS__PASSWORD
[smtp_options]
## Whether to enabled password reset via email, from LLDAP.
#enable_password_reset=true
## The SMTP server.
#server="smtp.gmail.com"
## The SMTP port.
#port=587
## How the connection is encrypted, either "NONE" (no encryption), "TLS" or "STARTTLS".
#smtp_encryption = "TLS"
## The SMTP user, usually your email address.
#user="sender@gmail.com"
## The SMTP password.
#password="password"
## The header field, optional: how the sender appears in the email. The first
## is a free-form name, followed by an email between <>.
#from="LLDAP Admin <sender@gmail.com>"
## Same for reply-to, optional.
#reply_to="Do not reply <noreply@localhost>"

## Options to configure LDAPS.
## To set these options from environment variables, use the following format
## (example with "port"): LLDAP_LDAPS_OPTIONS__PORT
[ldaps_options]
## Whether to enable LDAPS.
#enabled=true
## Port on which to listen.
#port=6360
## Certificate file.
#cert_file="/data/cert.pem"
## Certificate key file.
#key_file="/data/key.pem"
```
- Add the apache conf file :
```
</VirtualHost>
</IfModule>
root@vps-8506c620:/var/www/cryptpad-bridge# cat /etc/apache2/sites-available/lldap.conf 
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

    # Configuration SSL (Certbot)
    SSLEngine on
    SSLCertificateFile /etc/letsencrypt/live/oauth.DOMAIN/fullchain.pem
    SSLCertificateKeyFile /etc/letsencrypt/live/oauth.DOMAIN/privkey.pem
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
- sudo certbot certonly --apache -d oauth.DOMAIN
- sudo a2ensite hydra.conf 
- sudo systemctl restart apache2

At this point, Hydra and LDAP are installed but they don't speak to them. It is normal, and they never do this. We need to install the SSO App
## SSO App
Ory Hydra only manage the OAuth and OIDC process. He doesn't have a fronted to let the user use its credentiald. It is for the reason we choose it by the way :)

We use this app to check credential against LDAP and let the user consent to give acces to the clients app its info
### Installation
- cd /opt
- sudo git clone https://github.com/aurionMail/sso
- cd  sso
- sudo npm install
- sudo cp .example.env .env
- sudo npm run build
- sudo npm run build:css
- sudo chown -R hydra:hydra /opt/sso/
- sudo nano .env and add the .env with your values. You can also add them to your .service file (next line) but a .env must be present (even empty) :
```
PORT=3030
BASE_URL=https://sso.DOMAIN
HYDRA_ADMIN_URL=http://localhost:4445
# Only used in paid version of Ory Hydra
ORY_API_KEY=YOUR_API_KEY
LDAP_URL=ldap://127.0.0.1:3890
LDAP_USER_DN_PATTERN=uid={username},ou=people,dc=DOMAIN,dc=org
WEBMAIL_DOMAIN_WP=https://officialweb.mail.DOMAIN
CRYPTPAD_DOMAIN_WP=https://pad.DOMAIN
CORE_API_URL=https://aurion.mail.DOMAIN
CORE_API_INTERNAL_SECRET=yourSecret
```
- sudo nano /etc/systemd/system/hydra-login-consent.service and add
```
[Unit]
Description=Ory Hydra Login and Consent Node App
After=network.target

[Service]
Type=simple
User=hydra
WorkingDirectory=/opt/sso
ExecStart=/usr/bin/npm run serve
Restart=always
RestartSec=5
[Install]
WantedBy=multi-user.target
```
- sudo systemctl daemon-reload
- sudo systemctl start hydra-login-consent.service
- sudo systemctl enable hydra-login-consent.service

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
- sudo nano /etc/apache2/sites-available/sso-le-ssl.conf and add reberse proxy

```                               
<IfModule mod_ssl.c>
<VirtualHost *:443>
    ServerName sso.DOMAIN

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

SSLCertificateFile /etc/letsencrypt/live/sso.DOMAIN/fullchain.pem
SSLCertificateKeyFile /etc/letsencrypt/live/sso.DOMAIN/privkey.pem
Include /etc/letsencrypt/options-ssl-apache.conf
</VirtualHost>
</IfModule>
```
## Cryptpad
To use cryptpad with Aurion, you can use this apache conf file. This custom conf file enable to serve the minimal bridge in iframe to pass secrets to cryptpad.

- To install, follow instrcutons at https://docs.cryptpad.org/en/admin_guide/installation.html 
- Config File : 
```
// SPDX-FileCopyrightText: 2023 XWiki CryptPad Team <contact@cryptpad.org> and contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

/*  DISCLAIMER:

    There are two recommended methods of running a CryptPad instance:

    1. Using a standalone nodejs server without HTTPS (suitable for local development)
    2. Using NGINX to serve static assets and to handle HTTPS for API server's websocket traffic

    We do not officially recommend or support Apache, Docker, Kubernetes, Traefik, or any other configuration.
    Support requests for such setups should be directed to their authors.

    If you're having difficulty difficulty configuring your instance
    we suggest that you join the project's Matrix channel.

    If you don't have any difficulty configuring your instance and you'd like to
    support us for the work that went into making it pain-free we are quite happy
    to accept donations via our opencollective page: https://opencollective.com/cryptpad

*/
module.exports = {
/*  CryptPad is designed to serve its content over two domains.
 *  Account passwords and cryptographic content is handled on the 'main' domain,
 *  while the user interface is loaded on a 'sandbox' domain
 *  which can only access information which the main domain willingly shares.
 *
 *  In the event of an XSS vulnerability in the UI (that's bad)
 *  this system prevents attackers from gaining access to your account (that's good).
 *
 *  Most problems with new instances are related to this system blocking access
 *  because of incorrectly configured sandboxes. If you only see a white screen
 *  when you try to load CryptPad, this is probably the cause.
 *
 *  PLEASE READ THE FOLLOWING COMMENTS CAREFULLY.
 *
 */

/*  httpUnsafeOrigin is the URL that clients will enter to load your instance.
 *  Any other URL that somehow points to your instance is supposed to be blocked.
 *  The default provided below assumes you are loading CryptPad from a server
 *  which is running on the same machine, using port 3000.
 *
 *  In a production instance this should be available ONLY over HTTPS
 *  using the default port for HTTPS (443) ie. https://cryptpad.fr
 *  In such a case this should be also handled by NGINX, as documented in
 *  cryptpad/docs/example.nginx.conf (see the $main_domain variable)
 *
 */
    httpUnsafeOrigin: 'https://pad.DOMAIN',

/*  httpSafeOrigin is the URL used for the 'sandbox' described above.
 *  If you're testing or developing with CryptPad on your local machine then
 *  it is appropriate to leave this blank. The default behaviour is to serve
 *  the main domain over port 3000 and to serve the sandbox content over port 3001.
 *
 *  This is not appropriate in a production environment where invasive networks
 *  may filter traffic going over abnormal ports.
 *  To correctly configure your production instance you must provide a URL
 *  with a different domain (a subdomain is sufficient).
 *  It will be used to load the UI in our 'sandbox' system.
 *
 *  This value corresponds to the $sandbox_domain variable
 *  in the example nginx file.
 *
 *  Note that in order for the sandboxing system to be effective
 *  httpSafeOrigin must be different from httpUnsafeOrigin.
 *
 *  CUSTOMIZE AND UNCOMMENT THIS FOR PRODUCTION INSTALLATIONS.
 */
     httpSafeOrigin: "https://sand.DOMAIN",

/*  httpAddress specifies the address on which the nodejs server
 *  should be accessible. By default it will listen on localhost
 *  (IPv4 & IPv6 if enabled). If you want it to listen on
 *  a specific address, specify it here. e.g '192.168.0.1'
 *
 */
    //httpAddress: 'localhost',

/*  httpPort specifies on which port the nodejs server should listen.
 *  By default it will serve content over port 3000, which is suitable
 *  for both local development and for use with the provided nginx example,
 *  which will proxy websocket traffic to your node server.
 *
 */
    httpPort: 3010,

/*  httpSafePort purpose is to emulate another origin for the sandbox when
 *  you don't have two domains at hand (i.e. when httpSafeOrigin not defined).
 *  It is meant to be used only in case where you are working on a local 
 *  development instance. The default value is your httpPort + 1.
 *
 */
    httpSafePort: 3011,

/*  Websockets need to be exposed on a separate port from the rest of
 *  the platform's HTTP traffic. Port 3003 is used by default.
 *  You can change this to a different port if it is in use by a
 *  different service, but under most circumstances you can leave this
 *  commented and it will work.
 *
 *  In production environments, your reverse proxy (usually NGINX)
 *  will need to forward websocket traffic (/cryptpad_websocket)
 *  to this port.
 *
 */
     websocketPort: 3013,

/*  CryptPad will launch a child process for every core available
 *  in order to perform CPU-intensive tasks in parallel.
 *  Some host environments may have a very large number of cores available
 *  or you may want to limit how much computing power CryptPad can take.
 *  If so, set 'maxWorkers' to a positive integer.
 */
    // maxWorkers: 4,

    /* =====================
     *       Sessions
     * ===================== */

    /*  Accounts can be protected with an OTP (One Time Password) system
     *  to add a second authentication layer. Such accounts use a session
     *  with a given lifetime after which they are logged out and need
     *  to be re-authenticated. You can configure the lifetime of these
     *  sessions here.
     *
     *  defaults to 7 days
     */
    //otpSessionExpiration: 7*24, // hours

    /*  Registered users can be forced to protect their account
     *  with a Multi-factor Authentication (MFA) tool like a TOTP
     *  authenticator application.
     *
     *  defaults to false
     */
    //enforceMFA: false,

    /* =====================
     *       Privacy
     * ===================== */

    /*  Depending on where your instance is hosted, you may be required to log IP
     *  addresses of the users who make a change to a document. This setting allows you
     *  to do so. You can configure the logging system below in this config file.
     *  Setting this value to true will include a log for each websocket connection
     *  including this connection's unique ID, the user public key and the IP.
     *  NOTE: this option requires a log level of "info" or below.
     *
     *  defaults to false
     */
    //logIP: false,

    /* =====================
     *         Admin
     * ===================== */

    /*
     *  CryptPad contains an administration panel. Its access is restricted to specific
     *  users using the following list and the management interface on the instance.
     *  To give access to the admin panel to a user account, just add their public signing
     *  key, which can be found on the settings page for registered users. Access can be
     *  revoked directly from the interface, unless you added the key below.
     *  Entries should be strings separated by a comma.
     *  adminKeys: [
     *      "[cryptpad-user1@my.awesome.website/YZgXQxKR0Rcb6r6CmxHPdAGLVludrAF2lEnkbx1vVOo=]",
     *      "[cryptpad-user2@my.awesome.website/jA-9c5iNuG7SyxzGCjwJXVnk5NPfAOO8fQuQ0dC83RE=]",
     *  ]
     *
     */
    adminKeys: [

    ],

    /* =====================
     *        STORAGE
     * ===================== */

    /*  Pads that are not 'pinned' by any registered user can be set to expire
     *  after a configurable number of days of inactivity (default 90 days).
     *  The value can be changed or set to false to remove expiration.
     *  Expired pads can then be removed using a cron job calling the
     *  `evict-inactive.js` script with node
     *
     *  defaults to 90 days if nothing is provided
     */
    //inactiveTime: 90, // days

    /*  CryptPad archives some data instead of deleting it outright.
     *  This archived data still takes up space and so you'll probably still want to
     *  remove these files after a brief period.
     *
     *  cryptpad/scripts/evict-archived.js is intended to be run daily
     *  from a crontab or similar scheduling service.
     *
     *  The intent with this feature is to provide a safety net in case of accidental
     *  deletion. Set this value to the number of days you'd like to retain
     *  archived data before it's removed permanently.
     *
     *  defaults to 15 days if nothing is provided
     */
    //archiveRetentionTime: 15,

    /*  It's possible to configure your instance to remove data
     *  stored on behalf of inactive accounts. Set 'accountRetentionTime'
     *  to the number of days an account can remain idle before its
     *  documents and other account data is removed.
     *
     *  Leave this value commented out to preserve all data stored
     *  by user accounts regardless of inactivity.
     */
     //accountRetentionTime: 365,

    /*  Starting with CryptPad 3.23.0, the server automatically runs
     *  the script responsible for removing inactive data according to
     *  your configured definition of inactivity. Set this value to `true`
     *  if you prefer not to remove inactive data, or if you prefer to
     *  do so manually using `scripts/evict-inactive.js`.
     */
    //disableIntegratedEviction: true,


    /*  Max Upload Size (bytes)
     *  this sets the maximum size of any one file uploaded to the server.
     *  anything larger than this size will be rejected
     *  defaults to 20MB if no value is provided
     */
    //maxUploadSize: 20 * 1024 * 1024,

    /*  Users with premium accounts (those with a plan included in their customLimit)
     *  can benefit from an increased upload size limit. By default they are restricted to the same
     *  upload size as any other registered user.
     *
     */
    //premiumUploadSize: 100 * 1024 * 1024,

    /* =====================
     *   DATABASE VOLUMES
     * ===================== */

    /*
     *  CryptPad stores each document in an individual file on your hard drive.
     *  Specify a directory where files should be stored.
     *  It will be created automatically if it does not already exist.
     */
    filePath: './datastore/',

    /*  CryptPad offers the ability to archive data for a configurable period
     *  before deleting it, allowing a means of recovering data in the event
     *  that it was deleted accidentally.
     *
     *  To set the location of this archive directory to a custom value, change
     *  the path below:
     */
    archivePath: './data/archive',

    /*  CryptPad allows logged in users to request that the server 
     *  store particular documents indefinitely. This is called 'pinning'.
     *  Pin requests are stored in a pin-store. The location of this store is
     *  defined here.
     */
    pinPath: './data/pins',

    /*  if you would like the list of scheduled tasks to be stored in
        a custom location, change the path below:
    */
    taskPath: './data/tasks',

    /*  if you would like users' authenticated blocks to be stored in
        a custom location, change the path below:
    */
    blockPath: './block',

    /*  CryptPad allows logged in users to upload encrypted files. Files/blobs
     *  are stored in a 'blob-store'. Set its location here.
     */
    blobPath: './blob',

    /*  CryptPad stores incomplete blobs in a 'staging' area until they are
     *  fully uploaded. Set its location here.
     */
    blobStagingPath: './data/blobstage',

    decreePath: './data/decrees',

    /* CryptPad supports logging events directly to the disk in a 'logs' directory
     * Set its location here, or set it to false (or nothing) if you'd rather not log
     */
    logPath: './data/logs',

    /* =====================
     *       Debugging
     * ===================== */

    /*  CryptPad can log activity to stdout
     *  This may be useful for debugging
     */
    logToStdout: true,

    /* CryptPad can be configured to log more or less
     * the various settings are listed below by order of importance
     *
     * silly, verbose, debug, feedback, info, warn, error
     *
     * Choose the least important level of logging you wish to see.
     * For example, a 'silly' logLevel will display everything,
     * while 'info' will display 'info', 'warn', and 'error' logs
     *
     * This will affect both logging to the console and the disk.
     */
    logLevel: 'info',

    /*  clients can use the /settings/ app to opt out of usage feedback
     *  which informs the server of things like how much each app is being
     *  used, and whether certain clientside features are supported by
     *  the client's browser. The intent is to provide feedback to the admin
     *  such that the service can be improved. Enable this with `true`
     *  and ignore feedback with `false` or by commenting the attribute
     *
     *  You will need to set your logLevel to include 'feedback'. Set this
     *  to false if you'd like to exclude feedback from your logs.
     */
    logFeedback: false,

    /*  CryptPad supports verbose logging
     *  (false by default)
     */
    verbose: false,

    /*  Surplus information:
     *
     *  'installMethod' is included in server telemetry to voluntarily
     *  indicate how many instances are using unofficial installation methods
     *  such as Docker.
     *
     */
    installMethod: 'unspecified',
};
```
- The apache conf file :
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
  # ORDERED PROXY RULES (L'ordre ici est CRUCIAL pour Apache)
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

  # Mapping physique du fichier
  Alias "/bridge-minimal.html" "/var/www/aurion-bridges/bridge-minimal.html"

  <Location "/bridge-minimal.html">
     # Sécurité CSP pour autoriser ton Webmail
     Header always set Content-Security-Policy "frame-ancestors https://web.DOMAIN https://sso.DOMAIN"
     
     # Autoriser Apache à servir ce fichier local
     Require all granted
  </Location>

 Alias "/bridge-sand.html" "/var/www/aurion-bridges/bridge-sand.html"

  <Location "/bridge-sand.html">
     # Sécurité CSP pour autoriser ton Webmail
     Header always set Content-Security-Policy "frame-ancestors https://pad.DOMAIN https://web.DOMAIN https://sso.DOMAIN"

     # Autoriser Apache à servir ce fichier local
     Require all granted
  </Location>


  # On conserve la limite de taille pour l'ensemble du vhost
  LimitRequestBody 157286400

</VirtualHost>

```
- Now, it is time to add the SSO part : follow instrctutions at https://github.com/cryptpad/sso 
- Here is the config file :
```
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
        name: 'Aurion SSO',
        type: 'oidc',
        url: 'https://oauth.DOMAIN',
        client_id: 'cryptpad',
        client_secret: 'your_secret',
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
## Install Webmail

1. Define your installation paths and app user:
```bash
   export DEPLOY_DIR="/var/www/bulwark-webmail"
   export APP_USER="www-data"

```
[ -d "$DEPLOY_DIR/data" ] && sudo mv "$DEPLOY_DIR/data" /tmp/bulwark-data-bak

sudo mkdir -p "$DEPLOY_DIR"

LATEST_URL=$(curl -s [https://api.github.com/repos/YOUR_GITHUB_REPO/releases/latest](https://api.github.com/repos/YOUR_GITHUB_REPO/releases/latest) | jq -r '.assets[] | select(.name=="bulwark-webmail.tar.gz") | .browser_download_url')
curl -L -s -o /tmp/bulwark-webmail.tar.gz "$LATEST_URL"

sudo tar -xzf /tmp/bulwark-webmail.tar.gz -C "$DEPLOY_DIR"
rm -f /tmp/bulwark-webmail.tar.gz

if [ -d "/tmp/bulwark-data-bak" ]; then
  sudo mv /tmp/bulwark-data-bak "$DEPLOY_DIR/data"
else
  sudo mkdir -p "$DEPLOY_DIR/data/settings" "$DEPLOY_DIR/data/admin" "$DEPLOY_DIR/data/admin-state"
fi



- Install Node production dependencies as the application user:
```bash
cd "$DEPLOY_DIR"
sudo -u $APP_USER npm install --omit=dev --no-audit --ignore-scripts --no-fund

```


- Apply safe permissions across the application directory:
```bash
sudo chown -R $APP_USER:$APP_USER "$DEPLOY_DIR"
sudo find "$DEPLOY_DIR" -type d -exec chmod 755 {} \;
sudo find "$DEPLOY_DIR" -type f -exec chmod 644 {} \;

# Restore execution privileges for binaries
if [ -d "$DEPLOY_DIR/node_modules/.bin" ]; then
  sudo chmod -R 755 "$DEPLOY_DIR/node_modules/.bin"
  sudo find "$DEPLOY_DIR/node_modules/next/dist/bin" -type f -exec chmod 755 {} \; 2>/dev/null || true
fi

```

- Create a service file `/etc/systemd/system/bulwark-webmail.service`:
```ini
[Unit]
Description=Bulwark Webmail Service
After=network.target

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=/var/www/bulwark-webmail
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


- Enable and start the background service:
```bash
sudo systemctl daemon-reload
sudo systemctl enable --now bulwark-webmail

```

- Enable required Apache modules:
```bash
sudo a2enmod proxy proxy_http proxy_wstunnel rewrite headers

```


- Create `/etc/apache2/sites-available/bulwark-webmail.conf` (replace `your-domain.com`, `127.0.0.1`, and `3000` with your configuration):
```apache
<VirtualHost *:80>
    ServerName your-domain.com

    ProxyRequests Off
    ProxyPreserveHost On
    ProxyVia Full

    <Proxy *>
        Require all granted
    </Proxy>

    # Next.js WebSockets routing
    RewriteEngine On
    RewriteCond %{HTTP:Upgrade} =websocket [NC]
    RewriteRule ^/(.*)           ws://127.0.0.1:3000/$1 [P,L]

    # HTTP Proxy
    ProxyPass / http://127.0.0.1:3000/
    ProxyPassReverse / http://127.0.0.1:3000/

    # Security Headers
    RequestHeader set X-Forwarded-Proto "http"
    RequestHeader set X-Forwarded-Port "80"
    Header always set X-Content-Type-Options "nosniff"
    Header always set X-Frame-Options "SAMEORIGIN"

    ErrorLog ${APACHE_LOG_DIR}/bulwark-webmail-error.log
    CustomLog ${APACHE_LOG_DIR}/bulwark-webmail-access.log combined
</VirtualHost>

```


- Enable the virtual host and restart Apache:
```bash
sudo a2ensite bulwark-webmail.conf
sudo systemctl restart apache2

```
- `sudo certbot --apache -d your-domain.com`

## Aurion API
sudo mkdir aurion-core

cd aurion-core/

sudo wget https://github.com/AurionMail/core-api/releases/download/0.0.2/aurion-api

sudo nano .env

sudo -u postgres psql

postgres=# CREATE DATABASE aurionapidb OWNER aurionuser;
CREATE DATABASE
postgres=# CREATE USER aurioapinuser WITH PASSWORD 'pass';
CREATE ROLE
postgres=# CREATE DATABASE aurionapi OWNER aurioapinuser;
CREATE DATABASE
postgres=# \c aurionapi
You are now connected to database "aurionapi" as user "postgres".
aurionapi=# GRANT ALL ON SCHEMA public TO aurioapinuser;
GRANT
aurionapi=# ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO aurioapinuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO aurioapinuser;
ALTER DEFAULT PRIVILEGES
ALTER DEFAULT PRIVILEGES
aurionapi=# exit

sudo wget https://raw.githubusercontent.com/AurionMail/core-api/refs/heads/main/migrations/init.sql


psql -h localhost -U aurionuser -d auriondb -f migrations/init.sql

sudo chmod -R 750 ./aurion-core
sudo chown -R www-data:www-data ./aurion-core
sudo chmod +x ./aurion-api


Create the file /etc/systemd/system/aurion.service:

[Unit]
Description=Aurion Core Server
After=network.target postgresql.service

[Service]
Type=simple
User=www-data
WorkingDirectory=/var/www/aurion
ExecStart=/var/www/aurion/aurion-api
Restart=always
RestartSec=5
EnvironmentFile=/var/www/aurion/.env

[Install]
WantedBy=multi-user.target

Enable and start the service:

sudo systemctl daemon-reload
sudo systemctl enable aurion
sudo systemctl start aurion

conf apache

<VirtualHost *:80>
    ServerName aurion.mail.DOMAIN

    ProxyPreserveHost On
    ProxyPass / http://localhost:8070/
    ProxyPassReverse / http://localhost:8070/

    Header always set X-Content-Type-Options "nosniff"
    Header always set X-Frame-Options "DENY"
    Header always set X-XSS-Protection "1; mode=block"

    ErrorLog ${APACHE_LOG_DIR}/aurion-error.log
    CustomLog ${APACHE_LOG_DIR}/aurion-access.log combined
RewriteEngine on
RewriteCond %{SERVER_NAME} =aurion.mail.DOMAIN
RewriteRule ^ https://%{SERVER_NAME}%{REQUEST_URI} [END,NE,R=permanent]
</VirtualHost>


- then cerbot

# Configure Auth

### Config for clients
#### Bulwark + Stalwart

  sudo ./hydra create client   --endpoint http://127.0.0.1:4445   --id stalwart   --name "AurionMail Webmail"   --secret "hdd514sdduiuriuge"   --access-token-strategy jwt   --audience "stalwart"   --grant-type authorization_code,refresh_token   --response-type code   --scope openid,profile,email,offline_access   --redirect-uri "https://officialweb.mail.DOMAIN/auth/callback,https://officialweb.mail.DOMAIN/en/auth/callback,https://officialweb.mail.DOMAIN/fr/auth/callback"   --token-endpoint-auth-method client_secret_post   --skip-consent

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
  --redirect-uri "https://pad.DOMAIN/ssoauth" \
  --token-endpoint-auth-method client_secret_basic \
  --skip-consent

 ### Conf Bulwark

Oauth : Y 
OAuth Only : Y
OAuthClientID: stalwart 
OAuth Client Secret : secret 
OAuth Issuer URL : https://auth.DOMAIN
Auto SSO : Y 

### Conf Stalwart

Authentication->Directories 

Issuer URL : https://oauth.DOMAIN
Required Audience : null
Required Scopes : null
Username Claim : email
Name Claim : name 
Groups Claim : groups