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
