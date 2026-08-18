# Aurion Installation Tutorial with Orchestra
## Stalwart Web Server
Run the [Installation Script](https://stalw.art/docs/install/platform/linux/) provided by Stalwart and follow the standard configuration.
- add the webserver conf file, add https and enable it
    - [apache](./conf/apache/mail.conf)
    - [nginx](./conf/nginx/mail.domain)

Warning : We will soon enable the OIDC provider in stalwart. As a result, we won't be able to connect to admin account in admin webUI. So, you need to add the env variable STALWART_RECOVERY_ADMIN=admin:STALWART_ADMIN_PASSWORD.
- sudo nano /etc/stalwart/stalwart.env
- Now, go to admin/Settings/x:Http/HttpSecurity/singleton and check permissve CORS to allow bulwark to connect.
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
## Aurion API
- sudo -u postgres psql
- CREATE USER aurionuser WITH PASSWORD AURION_DB_PASSWORD;
- CREATE DATABASE auriondb OWNER aurionuser;
- \c auriondb
- GRANT ALL ON SCHEMA public TO aurionuser;
- ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO aurionuser;
- ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO aurionuser;
## Aurion Orchestra
- download lates binary and edit .env
- launch orchestra
- you will see in logs the migrations for hydra and Aurion API happening
- after that, you will a link to finsih install of cryptpad, use it
- you will see a link to finish install of Bulwark webmail, use it
- That's it !
# Configure Auth
All we need is now installed. We must now configure the SSO.
## Config Hydra
cd /path_orchestra/data/runtime/hydra
### Bulwark + Stalwart
```bash
  ./hydra create oauth2-client \
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
  ./hydra create oauth2-client \
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
#### Aurion PGP Plugin
To use Bulwark with Aurion, you need the Aurion PGP Plugin. This is the central part of AurionMail as this plugin enble users to encrypt mails and cryptpad documents.

Now, because of restrcitions in plugin system of Bulwark, we can't just provide the zip file of the plugin. But don't worry ! It is very simple.
- Download https://github.com/AurionMail/bulwark-pgp-plugin/releases/download/1.0.0/index.js 
- Download https://github.com/AurionMail/bulwark-pgp-plugin/releases/download/1.0.0/manifest.json
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