---
title: "LDAP / SSO"
description: "How to Auth your users"
weight: 20
draft: false
tags:
  - deployment
  - ldap
  - SSO
---
# LDAP or External SSO
AurionMail works
- with an external IdP. This is the source of truth for users, but end-users will need 2 passwords.
- with an LDAP service. In this case, only one password is needed.

If you have already a LDAP service or want to use an external IdP, you can ignore this.
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
    - [apache](../../examples/apache/ldap.conf)
    - [nginx](../../examples/nginx/ldap.domain)