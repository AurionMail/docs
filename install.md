# Aurion Installation Tutorial
This tutorial covers the parts in which AurionMail is involved. This tutorial covers installation with Stalwart, Bulwark, Ory Hydra, LLDAP, CryptPad and all you need.
## Prerequisites
You need a domain name. It is referenced as `DOMAIN_REPLACE_ME` during this tuto. You will need to replace in commands and conf files.
We assume this domain will send emails. Add these subdomains to its DNS Zone :
- mail. : used by Stalwart
- web. : used by the webmail Bulwark
- oauth. used by Hydra Backend
- sso. : used by SSO Frontend
- pad. used by Cryptpad
- sand. used by Cryptpad
- ldap : used by lldap webAdmin UI
- api : used by Aurion Core API

For testing with up to 30 users, 2GB cheap VPS is enough. In this tutorial, we will use
- debian 13
- apache2 or NGINX
- certbot
- postgresql for the Aurion API DB
- nodeJS 24 LTS
## Cheatsheet

| Service |  Port Usage | Address & Port | Domain | User | Update type | Path | in Orchestra |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **LLDAP** |  UI | `127.0.0.1:17170` | `ldap.` | `lldap` | `AUTO (package manager)` | N/A | ❌ No |
| **LLDAP** | LDAP (Protocol) | `127.0.0.1:3890` | - | `lldap` | `AUTO (package manager)` | N/A | ❌ No |
| **Ory Hydra** | Authentication (Auth) | `127.0.0.1:4444` | `oauth.` | `aurion` | `MANUAL` |/home/aurion/aurionmail/hydra | 🟢 Yes |
| **Ory Hydra** | Administration (Admin) | `127.0.0.1:4445` | - | `aurion` | `MANUAL` | /home/aurion/aurionmail/hydra| 🟢 Yes |
| **SSO App** | Application SSO | `127.0.0.1:3030` | `sso.` | `aurion` | `MANUAL` |/home/aurion/aurionmail/sso | 🟢 Yes |
| **Cryptpad** | Web App  | `127.0.0.1:3010` | `pad.` / `sand.` | `pad` | `MANUAL` |/home/pad/cryptpad/ | 🟢 Yes |
| **Cryptpad** | WebSockets | `127.0.0.1:3013` | `pad.` / `sand.` | `pad` | `MANUAL` | /home/pad/cryptpad| 🟢 Yes |
| **Bulwark Webmail** | Webmail UI | `127.0.0.1:3000` | `web.` | `bulwark` | `MANUAL` |/home/bulwark/webmail | 🟢 Yes |
| **Aurion API** | API | `127.0.0.1:8070` | `api.` | `aurion` | `MANUAL` | /home/aurion/aurionmail/api | 🟢 Yes |
| **Stalwart** | Mail Server | `127.0.0.1:8080` | `mail.` | `stalwart` | `MANUAL` | /opt/stalwart | ❌ No |
| **Bridges** | Bridges | *Integrated with reverse proxy* | - | `aurion` | `MANUAL` |/home/aurion/aurionmail/bridges  | 🟢 Yes |
## Alternative methods
### Orchestra
If you want something which works in minutes, without installing node, you can use [Aurion Orchestra](./install_with_orchestra.md). It is a single GO binary with 
- Cryptpad (without Collabora)
- Bulwark
- Hydra + SSO
- Aurion API
- node

You have just one port and one NGINX file to manage. All complicated configuration is done by the binary. It's magic ! This is not recomanded if you have already installed Cryptpad or if you want to entierely keep control on your configuration, but it is the easier way to start with Aurion. It is experimental, so if you have bugs, something weird, open an issue !

To install with orchestra : [Install with Orchestra](./install_with_orchestra.md)
### Docker
We profilde Docker for Orchestra. See [Install with Orchestra and Docker](./install_with_docker.md)
### Installation Script
You can use the [installation script](install.sh) to install all or just parts of the system. If you use it, at the end, you will have to Add the Aurion PGP Plugin to bulwark. This step can't be automatised.
## Users
We need to create 3 users : `aurion`, `bulwark` and `pad`. `aurion` will handle the auth of the users, keys and core API. 
- useradd -s /bin/false -m aurion
- useradd -s /bin/false -m bulwark
- useradd -s /bin/false -m pad
## Secrets
You will need to generate some secrets during the installation process. You can use `openssl rand -base64 100 | tr -dc 'a-zA-Z0-9' | head -c 64; echo` to do it and replace
### LDAP
- LDAP_JWT
### Hydra
- HYDRA_PASSWORD
- HYDRA_PAIRWISE_SALT
- HYDRA_SYSTEM_SECRET
### Stalwart
- STALWART_ADMIN_PASSWORD
### Bulwark
- SECRET_BULWARK_SSO
### Cryptpad
- SECRET_CRYPTPAD_SSO
### Aurion API
- AURION_API_INTERNAL_SECRET
- AURION_JWT_SECRET
- AURION_DB_PASSWORD
## LDAP
- We use lldap from the [debian repo](https://software.opensuse.org//download.html?project=home%3AMasgalor%3ALLDAP&package=lldap) :
```
echo 'deb http://download.opensuse.org/repositories/home:/Masgalor:/LLDAP/Debian_13/ /' | sudo tee /etc/apt/sources.list.d/home:Masgalor:LLDAP.list
curl -fsSL https://download.opensuse.org/repositories/home:Masgalor:LLDAP/Debian_13/Release.key | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/home_Masgalor_LLDAP.gpg > /dev/null
sudo apt update
```
- sudo apt install lldap lldap-extras
- edit conf file at `/etc/lldap/lldap_config.toml`
    - ldap_host = "127.0.0.1"
    - http_host = "127.0.0.1"
    - jwt_secret = "LDAP_JWT"
    - ldap_base_dn = "dc=DOMAINSTART,dc=DOMAINEND" :  for reference, with aurionmail.org, we would use dc=aurionmail,dc=org
The default admin user is admin / password . Once connected throught the webUI, delete it and add a new admin user.
- add the webserver conf file, add https and enable it
    - [apache](./conf/apache/ldap.conf)
    - [nginx](./conf/nginx/ldap.domain)
## Install Aurion
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
- CREATE USER hydra PASSWORD 'HYDRA_PASSWORD';
- exit;
- nano /etc/postgresql/17/main/pg_hba.conf
- add `host    all             all             127.0.0.1/32            scram-sha-256`
- `psql -U hydra -W -h 127.0.0.1`
- type password to check

- psql -d hydra
- GRANT ALL ON SCHEMA public TO hydra;
- GRANT USAGE ON SCHEMA public TO hydra;
- ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO hydra;
- ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO hydra;
- CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
- GRANT EXECUTE ON FUNCTION uuid_generate_v4() TO hydra;
- \q

- nano /home/aurion/aurionmail/hydra/config/hydra.yml
- paste the content of [Hydra Conf file](./conf/hydra/hydra.yml)
- apply migrations with /home/aurion/aurionmail/hydra/bin/hydra -c /home/aurion/aurionmail/hydra/config/hydra.yml migrate sql up

- nano /etc/systemd/system/hydra.service and paste the content of [hydra.service](./conf/systemd/hydra.service)
- systemctl enable hydra.service
- systemctl start hydra.service
- systemctl status hydra.service to check if all is OK
- add the webserver conf file, add https and enable it
    - [apache](./conf/apache/oauth.conf)
    - [nginx](./conf/nginx/oauth.domain)

At this point, Hydra and LDAP are installed but they don't speak to them. It is normal, and they never do this. We need to install the SSO App
## SSO App
Ory Hydra only manage the OAuth and OIDC process. It doesn't have a frontend to let users use their credentials. It is for the reason we choose it by the way :)

We use this app to check credential against LDAP and let the user consent to give acces to the clients app its info
### Installation
- cd /home/aurion/aurionmail/sso
- cp .example.env .env
- nano .env and add the .env with [your values](./conf/env/sso/.env). You can also add them to your .service file (next line) but a .env must be present (even empty) :
- sudo nano /etc/systemd/system/aurion-sso.service and add the content of the [service file](./conf/systemd/aurion-sso.service)
- sudo systemctl daemon-reload
- sudo systemctl start aurion-sso.service
- sudo systemctl enable aurion-sso.service
- add the webserver conf file, add https and enable it
    - [apache](./conf/apache/sso.conf)
    - [nginx](./conf/nginx/sso.domain)

> [!WARNING]
> After the first launch, visit /conf to get a secret you can use in the .env. Then restart. If you don't do that, a default value will be used. it is ok for testing but not advised at all in production !

## Cryptpad
- sudo -u pad bash
- wget https://github.com/AurionMail/docs/releases/download/0.0.2/cryptpad.zip 
- unzip cryptpad.zip 
- cd cryptpad
- find customize lib www -type f -exec sed -i 's/AURION_DOMAIN_REPLACE_ME/DOMAIN_REPLACE_ME/g' {} +
- cd config
- cp config.example.js config.js
- cp sso.example.js sso.js
- follow instructions at https://docs.cryptpad.org/en/admin_guide/installation.html from "configuration" or "onlyoffice" if you want. In fact, you can just add the crontab, the rest is already done or will be done in this guide.
- nano config.js and edit this values :
    - httpUnsafeOrigin: 'https://pad.DOMAIN_REPLACE_ME',
    - httpSafeOrigin: "https://sand.DOMAIN_REPLACE_ME",
    - httpAddress: '127.0.0.1',
    - httpPort: 3010,
    - httpSafePort: 3011,
    - websocketPort: 3013,
    - installMethod: 'aurion',
- nano /etc/systemd/system/cryptpad.service and paste the content of [cryptpad.service](./conf/systemd/cryptpad.service)
- add the webserver conf file, add https and enable it
    - [apache](./conf/apache/pad.conf)
    - [nginx](./conf/nginx/pad.domain)

- nano /home/pad/cryptpad/config/sso.js and add the content of [sso file](./conf/env/pad/sso.js)
- now you can run `systemctl status cryptpad.service` to get the admin temp key used to create the first admin and initiliaze Cryptpad.
## Stalwart Web Server
### Installation
Run the [Installation Script](https://stalw.art/docs/install/platform/linux/) provided by Stalwart and follow the standard configuration.
- add the webserver conf file, add https and enable it
    - [apache](./conf/apache/mail.conf)
    - [nginx](./conf/nginx/mail.domain)

Warning : We will soon enable the OIDC provider in stalwart. As a result, we won't be able to connect to admin account in admin webUI. So, you need to add the env variable STALWART_RECOVERY_ADMIN=admin:STALWART_ADMIN_PASSWORD.
- sudo nano /etc/stalwart/stalwart.env
- Now, go to admin/Settings/x:Http/HttpSecurity/singleton and check permissve CORS to allow bulwark to connect.
## Bulwark Webmail
Some servers do not have enough CPU to build the app, so we let github build it and we download.  
- sudo -u bulwark bash
- wget https://github.com/bulwarkmail/webmail/releases/download/1.7.8/bulwark-standalone-1.7.8-linux-amd64.tar.gz 
- tar -xvf bulwark-standalone-1.7.8-linux-amd64.tar.gz
- sudo nano /etc/systemd/system/bulwark-webmail.service and add the content of the [service file](./conf/systemd/bulwark-webmail.service)
- nano .env.local and add the content of [.env.local file](./conf/env/bulwark/.env.local).
- sudo systemctl daemon-reload
- sudo systemctl enable --now bulwark-webmail
- add the webserver conf file, add https and enable it
    - [apache](./conf/apache/web.conf)
    - [nginx](./conf/nginx/web.domain)
- now you can run `systemctl status bulwark-webmail.service` to get the admin temp key used to create the first admin and initiliaze the webmail.
## Aurion API
- cd /home/aurion/aurionmail/api
- sudo nano .env and add the content of [.env file](./conf/env/api/.env)

- sudo -u postgres psql
- CREATE USER aurionuser WITH PASSWORD AURION_DB_PASSWORD;
- CREATE DATABASE auriondb OWNER aurionuser;
- \c auriondb
- GRANT ALL ON SCHEMA public TO aurionuser;
- ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO aurionuser;
- ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO aurionuser;
- exit
- cd /home/aurion/aurionmail/api/migrations
- psql -h localhost -U aurionuser -d auriondb -f init.sql
- sudo chmod -R 750 ./aurion-core
- sudo chmod +x /home/aurion/aurionmail/api/aurion-api
- sudo nano /etc/systemd/system/aurion.service and add the content of [service file](./conf/systemd/aurion.service)
- sudo systemctl daemon-reload
- sudo systemctl enable aurion
- sudo systemctl start aurion
- add the webserver conf file, add https and enable it
    - [apache](./conf/apache/api.conf)
    - [nginx](./conf/nginx/api.domain)
## Bridges
- cd /home/aurion/aurionmail/bridges
- find . -type f -name "*.html" -exec sed -i 's/DOMAIN_TO_REPLACE/DOMAIN_REPLACE_ME/g' {} +
- chmod 711 /home/aurion
- chmod 711 /home/aurion/aurionmail
- chmod -R 755 /home/aurion/aurionmail/bridges
# Configure Auth
All we need is now installed. We must now configure the SSO.
## Config Hydra
cd /home/aurion/aurionmail/hydra/bin
### Bulwark + Stalwart
```bash
  sudo ./hydra create oauth2-client \
  --endpoint http://127.0.0.1:4445 \
  --id stalwart \
  --name "AurionMail Webmail" \
  --secret "SECRET_BULWARK_SSO" \
  --access-token-strategy jwt \
  --audience "stalwart" \
  --grant-type authorization_code,refresh_token \
  --response-type code \
  --scope openid,profile,email,offline_access \
  --redirect-uri "https://web.DOMAIN_REPLACE_ME/auth/callback,https://web.DOMAIN_REPLACE_ME/en/auth/callback,https://web.DOMAIN_REPLACE_ME/fr/auth/callback" \
  --token-endpoint-auth-method client_secret_post \
  --skip-consent
```
### Cryptpad
```bash
sudo ./hydra create oauth2-client \
  --endpoint http://127.0.0.1:4445 \
  --id cryptpad \
  --name "CryptPad" \
  --secret "SECRET_CRYPTPAD_SSO" \
  --access-token-strategy jwt \
  --grant-type authorization_code,refresh_token \
  --response-type code \
  --scope openid,profile,email,offline_access \
  --redirect-uri "https://pad.DOMAIN_REPLACE_ME/ssoauth" \
  --token-endpoint-auth-method client_secret_basic \
  --skip-consent
```
## Config clients
### Bulwark
#### Settings
Go to admin ui : https://web.DOMAIN_REPLACE_ME/admin then Authentication :
- Oauth : Activated
- OAuth Only : Activated
- OAuthClientID: stalwart 
- OAuth Client Secret : SECRET_BULWARK_SSO 
- OAuth Issuer URL : https://oauth.DOMAIN_REPLACE_ME
- Auto SSO : Activated
#### Aurion PGP Plugin
To use Bulwark with Aurion, you need the Aurion PGP Plugin. This is the central part of AurionMail as this plugin enble users to encrypt mails and cryptpad documents.

Now, because of restrcitions in plugin system of Bulwark, we can't just provide the zip file of the plugin. But don't worry ! It is very simple.
- Download https://github.com/AurionMail/bulwark-pgp-plugin/releases/download/2.0.1/index.js 
- Download https://github.com/AurionMail/bulwark-pgp-plugin/releases/download/2.0.1/manifest.json
- The file you need to edit is the manifest. Indeed, Bulwark require all Origin used by a plugin to be in the manifest. So, you need to replace
```
"httpOrigins": [
    "https://keys.openpgp.org",
    "https://api.DOMAIN_REPLACE_ME"
  ],
    "frameOrigins": [
    "https://pad.DOMAIN_REPLACE_ME"
  ],
```
by your real domain
- Zip `index.js` and `manifest.json` into a zip file and upload it in administration part of Bulwark
- Enforce this plugin and go to the plugin Settings to write the API URL, OAuth URL and Pad URL.

### Stalwart
Navigate to webUI with your admin account, then : Authentication->Directories 
- Issuer URL : https://oauth.DOMAIN_REPLACE_ME
- Required Audience : null
- Required Scopes : null
- Username Claim : email
- Name Claim : name 
- Groups Claim : groups
- don't forget to add your domain to username domain.
Navigate to Authentication -> General: Select your created directory as the primary authentication directory
### Cryptpad
Nothing to do, it has been configured with "nano /home/pad/cryptpad/config/sso.js and add the content [sso file](./conf/env/pad/sso.js)" Remember ?
## And now ?
You can go to [usage.md](./usage.md).