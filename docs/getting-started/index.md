---
title: "Getting started"
description: "All you need to install AurionMail"
weight: 10
draft: false
tags:
  - deployment
---

# Aurion Installation Tutorial
This tutorial covers installation with Stalwart, Bulwark, Ory Hydra, LLDAP, CryptPad and all you need.
## Prerequisites
### Domain Name
You need a domain name. This is mandatory. For development, you can create a .local domain if you want. It is referenced as `DOMAIN_REPLACE_ME` in the documentation. You will need to replace in commands and conf files.

All the following subdomain MUST be on the same domain :

- web. : used by the webmail Bulwark
- oauth. used by Hydra Backend
- sso. : used by SSO Frontend
- pad. used by Cryptpad
- sand. used by Cryptpad
- api : used by Aurion Core API

These subdomains can be ignored if you have already installed the services. They can be on a different domain.

- mail. : used by Stalwart
- ldap : used by lldap webAdmin UI (no need if you use external SSO or anoter LDAP provider)
### System
You need at least a AMD64 Linux system. 
For testing with up to 15 users, 2GB cheap VPS is enough. In this tutorial, we will use

- debian 13
- apache2 or NGINX
- certbot
- postgresql
- nodeJS 24 LTS
## Installation Methods
### Orchestra
If you want something which works in minutes, without installing node, you can use [Aurion Orchestra](./installation/binary.md). It is a single GO binary with 
- Cryptpad (without Collabora)
- Bulwark
- Hydra + SSO
- Aurion API
- node

You have just one port and one NGINX file to manage. All complicated configuration is done by the binary. It's magic ! This is not recomanded if you have already installed Cryptpad or if you want to entierely keep control on your configuration, but it is the easier way to start with Aurion. It is experimental, so if you have bugs, something weird, open an issue !

To install with orchestra : [Install with Orchestra](./installation/binary.md)
#### Binary Cheatsheet
| Service |  Port Usage | Address & Port | Domain | User | Update type | Path | in Orchestra |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **LLDAP** |  UI | `127.0.0.1:17170` | `ldap.` | `lldap` | `AUTO (package manager)` | N/A | ❌ No |
| **LLDAP** | LDAP (Protocol) | `127.0.0.1:3890` | - | `lldap` | `AUTO (package manager)` | N/A | ❌ No |
| **Stalwart** | Mail Server | `127.0.0.1:8080` | `mail.` | `stalwart` | `MANUAL` | /opt/stalwart | ❌ No |
| **Bridges** | AurionMail | `127.0.0.1:8090` | - | `aurion` | `MANUAL` | /home/aurion/orchestra  | 🟢 Yes |

### Docker
We profilde Docker for Orchestra. See [Install with Orchestra and Docker](./installation/docker.md)
### Advanced Method
It is the recommened method for people who want to keep all control on their data or have strict constraints in their system. For example, if you have already installed Cryptpad or Bulkwark and don't want to replace them, this is the method you should use.

#### Advanced Cheatsheet

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
