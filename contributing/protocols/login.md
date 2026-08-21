# Login (P1)
## Context
This operation happen when user want to access to webmail or cryptpad
## Modules involved
- login page of SSO
- Aurion Plugin
- sso iframe
- webmail iframe
## States
### Not connected
1. On login page, auth password is derivated from master password with Argon2ID. A secret with master password is created.
2. Secret Key is sended to webmail throught webmail iframe
3. On webmail, in Aurion Plugin, master password is got.
4. This master password is used to
    - derivate auth password to connect to Aurion Core API to get the API token
    - unlock keys
5. Aurion Token sent to SSO throught sso. It won't be used now but eventually in protocol `logout_all`.
### Already connected from a previous session
1. Login page skiped
2. on webmail, connect to Aurion API with token
3. Keys unlocked with an input from user or using the Dangerous key storage.