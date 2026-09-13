# Auth with external provider
## Concept
This feature enable authentication with an external IdP supporting OIDC. A master password is required to encrypt Aurion data.
## Basic configuration
Simply fill this values in the `.env`
```
# EXTERNAL_OIDC_ISSUER=Domain of your provider
# EXTERNAL_OIDC_CLIENT_ID=client_id
# EXTERNAL_OIDC_CLIENT_SECRET=client_secret
# EXTERNAL_OIDC_LOGOUT_URI=URL
# EXTERNAL_OIDC_FULL_LOGOUT_URI=URL
```
`EXTERNAL_OIDC_LOGOUT_URI` is the URL used to logout from the external IdP when this logout is initialized from Aurion. This is the URL Aurionmail should use to logout the user from your external provider.
## Logout from other clients
`EXTERNAL_OIDC_FULL_LOGOUT_URI` is an optional parameter. It will be used if your IdP uses a full logout system, i.e. the user logout from a client, all other clients of the session must logout. In the case of AurionMail, we need to execute js in the navigator to ensure sensitive data is erased and also because Cryptpad doesn't support logout from SSO. So, to ensure this, when an app ask from logout, you must redirect with your reverse proxy to `oauth.domain/oauth2/sessions/logout`. AurionMail will logout and will redirect to `EXTERNAL_OIDC_FULL_LOGOUT_URI` with paramter `from_aurion=true`.