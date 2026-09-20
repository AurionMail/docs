# Login (E1) (Planned)
## Context
This operation happen when user want to access to webmail or cryptpad with an external IdP
## Modules involved
- login page of SSO
- Aurion Plugin
- sso iframe
- webmail iframe
## States
Even with an external IdP, (master SSO), we use our local SSO. Indeed, we must use our SSO to issue an exchange token used in webmail Plugin to get a jwt token to get keys. If, we don't use our local SSO, we can't generate the exchange token. A solution could be to auth the Plugin with OAuth but it add one step in workflow.

With external SSO, user have 2 passwords : Aurion Password to encrypt data and its master SSO password.

The architecture is Cryptpad / Webmail -> Aurion SSO -> External SSO
### Not connected
1. On login page, user is redirected to external SSO
2. User Auth with external SSO
3. User is redirected to Aurion SSO. Aurion SSO is therefore an OIDC client of external SSO
4. The page in aurion SSO is used to pass to webmail the plugin Aurion API exchange token
5. On webmail, in Aurion Plugin, master password is asked to user.
6. This master password is used to
    - derivate auth password to connect to Aurion Core API to get the API token
    - unlock keys
7. Aurion Token sent to SSO throught sso. It won't be used now but eventually in protocol `logout_all`.
### Already connected from a previous session
1. Login page skiped
2. on webmail, connect to Aurion API with token
3. Keys unlocked with an input from user or using the Dangerous key storage.