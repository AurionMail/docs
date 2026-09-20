---
title: "Stalwart Configuration"
description: "How to configure your mail server"
weight: 30
draft: false
tags:
  - deployment
  - stalwart
  - SSO
---
# Stalwart Install and Configuration
## Installation
Run the [Installation Script](https://stalw.art/docs/install/platform/linux/) provided by Stalwart and follow the standard configuration.
- add the webserver conf file, add https and enable it
    - [apache](../../examples/apache/mail.conf)
    - [nginx](../../examples/nginx/mail.domain)

Warning : We will soon enable the OIDC provider in stalwart. As a result, we won't be able to connect to admin account in admin webUI. So, you need to add the env variable `STALWART_RECOVERY_ADMIN=admin:STALWART_ADMIN_PASSWORD`. Of course, use a real password to replace `STALWART_ADMIN_PASSWORD`.
- sudo nano /etc/stalwart/stalwart.env
- Now, go to admin/Settings/x:Http/HttpSecurity/singleton and check permissve CORS to allow bulkwark to connect.
## Configuration
Navigate to webUI with your admin account, then : Authentication->Directories 
- Issuer URL : https://oauth.DOMAIN_REPLACE_ME. This is the URL of AurionMail OAuth service and not your external IdP if you have one.
- Required Audience : null
- Required Scopes : null
- Username Claim : email
- Name Claim : name 
- Groups Claim : groups
- don't forget to add your domain to username domain.
Navigate to Authentication -> General: Select your created directory as the primary authentication directory

At this point, you won't be able to login to webUI with basic credentials because the webUI doesn't OIDC. But this not an issue because you have set at the begining the admin password in the env.