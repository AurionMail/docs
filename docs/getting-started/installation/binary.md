---
title: "Installation with Binary Orchestra"
description: "Deployment procedure for installing AurionMail using the Orchestra binary."
weight: 40
draft: false
tags:
  - deployment
  - binary
  - SSO
---

# Installation with Binary Orchestra

This guide details the process for configuring dependencies (PostgreSQL), deploying the Aurion Orchestra binary, setting up the Nginx reverse proxy, and integrating the Bulwark PGP plugin. We assume Stalwart and LDAP/external IdP are ready.

## Database Setup (PostgreSQL)
### Ory Hydra Configuration
Switch to the PostgreSQL system user and create the database:

```bash
sudo -i -u postgres
createdb hydra
psql
```
Set the password encryption method and create the `hydra` database role:
```sql
ALTER SYSTEM SET password_encryption = 'scram-sha-256';
SELECT pg_reload_conf();
CREATE USER hydra WITH PASSWORD 'HYDRA_PASSWORD';
\q

```
Update your PostgreSQL authentication policy (e.g., in `/etc/postgresql/17/main/pg_hba.conf`) by adding the following rule:
```text
host    all             all             127.0.0.1/32            scram-sha-256
```
> [!INFO]
> You should replace `17` by your actual postgres version.

Verify access using the newly created credentials:
```bash
psql -U hydra -W -h 127.0.0.1

```
After entering your password, grant the required privileges and enable the UUID extension:
```sql
\c hydra
GRANT ALL ON SCHEMA public TO hydra;
GRANT USAGE ON SCHEMA public TO hydra;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO hydra;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO hydra;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
GRANT EXECUTE ON FUNCTION uuid_generate_v4() TO hydra;
\q
```
### Aurion API Configuration
Open the PostgreSQL administrative console:

```bash
sudo -u postgres psql
```
Create the dedicated user and database, then assign permissions:
```sql
CREATE USER aurionuser WITH PASSWORD 'AURION_DB_PASSWORD';
CREATE DATABASE auriondb OWNER aurionuser;
\c auriondb
GRANT ALL ON SCHEMA public TO aurionuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO aurionuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO aurionuser;
\q
```
## Deploying Aurion Orchestra
1. Create the non-privileged system user:
```bash
sudo useradd -s /bin/false -m aurion
```
2. Download and configure the binary:
* Fetch the latest release from the [AurionMail Orchestra repository](https://github.com/AurionMail/orchestra/releases).
* Update the `.env` file according to your environment settings.

3. Initial Run:
```bash
./aurion-orchestrator
```
Database migrations for Hydra and Aurion API will execute automatically. You should observe output similar to the following:
```text
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
...
2026/08/23 11:48:23 [webmail] Bulwark Webmail v1.8.1
2026/08/23 11:48:24 [cryptpad] 
=============================
Create your first admin account and customize your instance by visiting
https://pad.DOMAIN.org/install/#af8fcb1157b35a8dbc7ac956e62ccfa1427d2fcb16428b4aafa9e61cdd115485
==============================================================
...
==============================================================
  SETUP REQUIRED
  Token: b30214eb5c73587183d8086cdf5ba68bd21cbd6c40290bb0e948a00dd1384500
  Open:  http://<host>:3000/setup?token=b30214eb5c73587183d8086cdf5ba68bd21cbd6c40290bb0e948a00dd1384500
  Token expires in 1 hour.
==============================================================

```

> [!WARNING]
> After the first start, navigate to `https://sso.DOMAIN_REPLACE_ME/conf` to generate an OPRF secret required for OPAQUE authentication.
> Paste this value into your `.env` file and restart the binary. Do not retain default secrets in production environments.

## Reverse Proxy Setup (Nginx)

1. Generate TLS Certificates using Certbot:
```bash
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
2. Generate Diffie-Hellman Parameters (mandatory for cryptpad):
```bash
openssl dhparam -out /etc/nginx/dhparam.pem 4096
```
3. Configure Nginx HTTP Block for WebSockets:
Add the following map block inside the `http` section of `/etc/nginx/nginx.conf`:
```nginx
map $http_upgrade $connection_upgrade {
    default upgrade;
    ''      close;
}
```
4. Enable Site Configuration:
Copy the example configuration file from [NGINX conf file](../../examples/nginx/aurion_orchestra.conf) into `/etc/nginx/sites-available/`, replace all instances of `DOMAIN_REPLACE_ME` with your actual domain, and activate it:
```bash
sudo ln -s /etc/nginx/sites-available/aurion_orchestra.conf /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```
5. Complete Application Initialization:
Use the onboarding links printed in the log output to finalize setup for Cryptpad and Bulwark Webmail.
## Client & Authentication Setup
You can manage Orchestra as a system service using a standard systemd service unit (`orchestra.service`).
### Bulwark Setup (Aurion PGP Plugin)
AurionMail uses a dedicated PGP plugin for Bulwark Webmail to manage end-to-end encryption for emails and Cryptpad documents.

1. Download release 2.0.2 assets:
* [index.js](https://github.com/AurionMail/bulwark-pgp-plugin/releases/download/2.0.2/index.js?utm_source=gemini)
* [manifest.json](https://github.com/AurionMail/bulwark-pgp-plugin/releases/download/2.0.2/manifest.json?utm_source=gemini)

2. Edit `manifest.json` and replace placeholder domains with your production endpoints:
```json
"httpOrigins": [
  "https://keys.openpgp.org",
  "https://api.DOMAIN_REPLACE_ME"
],
"frameOrigins": [
  "https://pad.DOMAIN_REPLACE_ME"
]

```
3. Compress both `index.js` and `manifest.json` into a single `.zip` archive.
4. Upload the archive via the Bulwark administration panel.
5. Enable and enforce the plugin and update its settings with your API, OAuth, and Pad URLs.

## Next Steps
Your setup is complete. Go to [usage.md](../../usage/index.md).