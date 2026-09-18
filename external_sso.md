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