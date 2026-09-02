# Aurion Installation Tutorial with Docker
## Stalwart Web Server
Run the [Installation Script](https://stalw.art/docs/install/platform/linux/) provided by Stalwart and follow the standard configuration.
- add the webserver conf file, add https and enable it
    - [apache](./conf/apache/mail.conf)
    - [nginx](./conf/nginx/mail.domain)

Warning : We will soon enable the OIDC provider in stalwart. As a result, we won't be able to connect to admin account in admin webUI. So, you need to add the env variable STALWART_RECOVERY_ADMIN=admin:STALWART_ADMIN_PASSWORD.
- sudo nano /etc/stalwart/stalwart.env
- Now, go to admin/Settings/x:Http/HttpSecurity/singleton and check permissve CORS to allow bulwark to connect.
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

## Aurion Orchestra with Docker
- create a directory on your machine and put inside the [docker-compose.yml](https://github.com/AurionMail/orchestra/blob/main/docker-compose.yml) and [env file](https://github.com/AurionMail/orchestra/blob/main/.env.docker.example). Edit them (at least env file).
- rename `.env.docker.example` to `.env`
- `docker compose up`
- you will see in logs the migrations for hydra and Aurion API happening. At the end, you whould see something like this
```
2026/08/23 11:48:20 ==================================================
2026/08/23 11:48:20      Starting Aurion Orchestrator Binary          
2026/08/23 11:48:20 ==================================================
2026/08/23 11:48:20 [main] Config loaded. Domain: aurionmail.org, DataDir: /home/aurion/orchestra, ProxyPort: 8090
2026/08/23 11:48:20 [runner] Unpacking runtime assets to /home/aurion/orchestra/runtime...
2026/08/23 11:48:23 [main] Starting child services...
2026/08/23 11:48:23 [runner] Started service hydra (PID: 320466)
2026/08/23 11:48:23 [runner] Started service core-api (PID: 320467)
2026/08/23 11:48:23 [runner] Started service sso (PID: 320468)
2026/08/23 11:48:23 [runner] Started service cryptpad (PID: 320470)
2026/08/23 11:48:23 [runner] Started service webmail (PID: 320473)
2026/08/23 11:48:23 [main] Reverse Proxy listening on http://127.0.0.1:8090
2026/08/23 11:48:23 [core-api] (ERR) 2026/08/23 11:48:23 PostgreSQL database connection successful
2026/08/23 11:48:23 🚀 aurion-api server started on http://localhost:8070 (production)
2026/08/23 11:48:23 [hydra] Thank you for using Ory Hydra v26.2.0!
2026/08/23 11:48:23 [hydra] (ERR) time=2026-08-23T11:48:23Z level=info msg=No tracer configured - skipping tracing setup audience=application service_name=Ory Hydra service_version=v26.2.0
2026/08/23 11:48:23 [hydra] (ERR) time=2026-08-23T11:48:23Z level=info msg=Software quality assurance features are enabled. Learn more at: https://www.ory.sh/docs/ecosystem/sqa audience=application service_name=Ory Hydra service_version=v26.2.0
2026/08/23 11:48:23 [hydra] (ERR) time=2026-08-23T11:48:23Z level=info msg=Setting up http server on 0.0.0.0:4444 audience=application service_name=Ory Hydra service_version=v26.2.0
time=2026-08-23T11:48:23Z level=warning msg=HTTPS is disabled. Please ensure that your proxy is configured to provide HTTPS, and that it redirects HTTP to HTTPS. audience=application service_name=Ory Hydra service_version=v26.2.0
2026/08/23 11:48:23 [hydra] (ERR) time=2026-08-23T11:48:23Z level=info msg=Setting up http server on 0.0.0.0:4445 audience=application service_name=Ory Hydra service_version=v26.2.0
time=2026-08-23T11:48:23Z level=warning msg=HTTPS is disabled. Please ensure that your proxy is configured to provide HTTPS, and that it redirects HTTP to HTTPS. audience=application service_name=Ory Hydra service_version=v26.2.0
2026/08/23 11:48:23 [webmail] ▲ Next.js 16.2.11
2026/08/23 11:48:23 [webmail] - Local:         http://localhost:3000
- Network:       http://0.0.0.0:3000
✓ Ready in 0ms
2026/08/23 11:48:23 [sso] Listening on http://0.0.0.0:3030
2026/08/23 11:48:23 [webmail] Bulwark Webmail v1.8.1
2026/08/23 11:48:24 [cryptpad] =============================
2026/08/23 11:48:24 [cryptpad] Create your first admin account and customize your instance by visiting
https://pad.aurionmail.org/install/#af8fcb1157b35a8dbc7ac956e62ccfa1427d2fcb16428b4aafa9e61cdd115485
=============================
2026/08/23 11:48:24 [webmail] [INFO ] 2026-08-23T11:48:24.337Z Admin dashboard disabled (no ADMIN_PASSWORD set)
Admin dashboard initialized
2026/08/23 11:48:24 [webmail] 
==============================================================
  SETUP REQUIRED
  Token: b30214eb5c73587183d8086cdf5ba68bd21cbd6c40290bb0e948a00dd1384500
  Open:  http://<host>:3000/setup?token=b30214eb5c73587183d8086cdf5ba68bd21cbd6c40290bb0e948a00dd1384500
  Token expires in 1 hour. Restart the container to reissue.
==============================================================

2026/08/23 11:48:24 [webmail] [INFO ] 2026-08-23T11:48:24.357Z telemetry: scheduler not started {"consent":"off"}
2026/08/23 11:48:24 [webmail] [INFO ] 2026-08-23T11:48:24.370Z version-check: scheduler started {"nextInMs":30000}
```
- You see a link to finsih installing of cryptpad and Bulwark, use it now to do that without https ou wait for nginx conf to be enabled.
- you will see a link to finish install of Bulwark webmail, use it

> [!WARNING]
> After the first launch, visit sso.domain/conf to generate an OPRF secret which will be used for OPAQUE auth. Paste it in the .env file. Then relaunch. If you don't do that, a default value will be used. it is ok for testing but not advised at all in production !
### Reverse Proxy
- run
```
certbot certonly --webroot \
   -w /var/www/html \
   -d sand.DOMAIN_REPLACE_ME \
   -d pad.DOMAIN_REPLACE_ME \
   -d web.DOMAIN_REPLACE_ME \
   -d api.DOMAIN_REPLACE_ME \
   -d openpgpkey.DOMAIN_REPLACE_ME \
   -d oauth.DOMAIN_REPLACE_ME \
   -d sso.DOMAIN_REPLACE_ME
```
- run `openssl dhparam -out /etc/nginx/dhparam.pem 4096` if needed.
- add this in http bloc in `/etc/nginx/nginx.conf` :
```
map $http_upgrade $connection_upgrade {
        default upgrade;
        ''      close;
    }
```
- edit [NGINX conf file](./conf/nginx/aurion_orchestra.conf) and enable it with `sudo ln -s /etc/nginx/sites-available/aurion_orchestra.conf /etc/nginx/sites-enabled/`
- `sudo nginx -t`
- `sudo systemctl reload nginx`
- If you waited to finish installing Bulwark and Cryptpad, relaunch orchestra and finish setup.
# Configure Auth
## Config clients
### Bulwark
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
## And now ?
You can go to [usage.md](./usage.md).