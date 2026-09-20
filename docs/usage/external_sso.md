---
title: "How to use an external IdP"
description: "How to use AurionMail with an external IdP"
weight: 70
draft: false
tags:
  - deployment
  - SSO
---

# Usage
## Generating users
For better compatibilities with your existing systems, Aurion doesn't come with a built-in system to generate or create users. We relie on LDAP. As a result, you must create with your habitual workflow. If you installed LLDAP, it can be done throught the webUI. To initilaize an user account, you must populated name, mail and password field.

The password field is only used for initialize the user account on SSO. It will be used to authorize the user to initialize account. You won't be able to know its password.

To initialize their acount on the SSO, users simply go to sso.domain/init and fill their info.

> [!NOTE]
> If your system is automatised, you can simply give your users a link of this type to automatically fill their username and temporary password : `https://sso.domain/init?username=john.doe&tempPassword=TempSecret123`
## Ory Hydra
You can use the SSO + Hydra part to authenticate users to services others than Cryptpad and Bulwark. Go to the Ory Hydra documentation to add your new client in Hydra DB. For reference, here is a conf using stateless JWT you can inspire :
```bash
  sudo ./hydra create oauth2-client \
  --endpoint http://127.0.0.1:4445 \
  --id YOUR_COOL_APP \
  --name "Cool Name" \
  --secret "SECRET_YOUR_COOL_APP" \
  --access-token-strategy jwt \
  --audience "stalwart" \
  --grant-type authorization_code,refresh_token \
  --response-type code \
  --scope openid,profile,email,offline_access \
  --redirect-uri "https://YOUR_COOL_APP/auth/callback,https://web.DOMAIN_REPLACE_ME/fr/auth/callback" \
  --token-endpoint-auth-method client_secret_post \
  --skip-consent
```
## Installation with Orchestra
### Refining Cryptpad Conf with Orchestra
We choose to put the `config.js` file used to config apache in storage directory. As a result, it is freely editable by admins
### Updating
It is an advantage of using Orchestra, updating is very simple :
- go to Orchestra directory
- `rm -rf aurion-orchestrator aurion-orchestrator-linux-amd64.zip runtime`
- `wget https://github.com/AurionMail/orchestra/releases/download/VERSION_NUMBER/aurion-orchestrator-linux-amd64.zip`
- `unzip aurion-orchestrator-linux-amd64.zip`
- Done !

## Advices for users
At first visit of webmail, you need to go to settings-> Aurion PGP to generate or upload your PGP key. Once generated, you need to lock and unlock it before activating Cryptpad



# Auth with external provider
> [!CAUTION]
> Authenticating (login + logout) with external provider is currently experimental. If you managed to make this working with a provider not listed here, please make a PR !
## Concept
This feature enable authentication with an external IdP supporting OIDC. A master password is required to encrypt Aurion data.
## Basic configuration
Simply fill this values in the `.env`
```
# EXTERNAL_OIDC_ISSUER=Domain of your provider
# EXTERNAL_OIDC_CLIENT_ID=client_id
# EXTERNAL_OIDC_CLIENT_SECRET=client_secret
# EXTERNAL_OIDC_LOGOUT_URI=https://your-extranl-idp.domain/logout
# EXTERNAL_OIDC_FULL_LOGOUT_URI=https://your-extranl-idp.domain/session-logout-full
```
`EXTERNAL_OIDC_LOGOUT_URI` is the URL used to logout from the external IdP when this logout is initialized from Aurion. This is the URL Aurionmail should give to navigator to logout the user from your external provider.
## Logout from other clients
> [!TIP]
> This is helpful only if you have configured a feature like "Single Logout for RP-initiated Logout" on your IdP. If not, the next lines are not relevant. users will need to go to Aurion app to properly logout.


`EXTERNAL_OIDC_FULL_LOGOUT_URI` is an optional parameter. It will be used if your IdP uses a full logout system, i.e. the user logout from a client, all other clients of the session must logout. In the case of AurionMail, we need to execute js in the navigator to ensure sensitive data is erased and also because Cryptpad doesn't support logout from SSO. So, to ensure this, when an app ask from logout, you must redirect with your reverse proxy to `oauth.domain/oauth2/sessions/logout`. AurionMail will logout and will redirect to `EXTERNAL_OIDC_FULL_LOGOUT_URI` with paramter `from_aurion=true`.
## Example configurations
### Basic info
Here is some info you may need to configure your client.
 - We request data for these scopes : `openid profile email`
 - We use a `S256` code challenge method
 - Callback URL : `https://sso.domain/login/oidc/callback`
### Authelia
#### Basic
Add to your config file :
```yml
clients:
    - client_id: 'aurionmail'
    client_name: 'AurionMail'
    client_secret: 'your_cool_secret'
    token_endpoint_auth_method: 'client_secret_post'

    authorization_policy: 'one_factor'

    redirect_uris:
        - 'https://sso.domain/login/oidc/callback'
    scopes:
        - 'openid'
        - 'profile'
        - 'email'

    response_types:
        - 'code'
    grant_types:
        - 'authorization_code'
        - 'refresh_token'
```
#### RP Logout
You can add this to your nginx reverse proxy :
```
location = /logout {
        if ($arg_from_aurion != "true") {
            return 302 https://oauth.domain/oauth2/sessions/logout;
        }
        proxy_pass http://127.0.0.1:9091;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $http_host;
        proxy_set_header X-Forwarded-URI $request_uri;
    }
```