# External SSO (Planned)

## Description
- The external SSO is only used to authenticate users
- As a result, it can't provide a secret used for encryption, therefore users must get 2 passwords
- Aurion SSO acts as OIDC provider for Bulwarkmail and Cryptpad and OIDC client for the external SSO. In this configuration, LDAP is not used as source of truth for authenticate users
## Constraints
The main constraints are
- we need to keep our local SSO to to operations like logout All, change password, login
- Cryptpad and BulwarkMail  don't support OIDC backend logout
- We must execute javascript in navigator iframes when logout to guaratee encrypted but important data is removed from disk
- this js must be executed when we ask for logout from an app from aurionmail or from an external app from external SSO.
