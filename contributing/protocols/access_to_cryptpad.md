# Access to Cryptpad (P2)
## Context
This operation happen when an user want to access to Cryptpad
## Modules involved
- sand iframe
- pad iframe
- Aurion Plugin
- Cryptpad `ssoauth.js`
## States
### Not connected
User is redirected to webmail. Without `?from=aurion` parameter, user is redirected to webmail when trying to login to cryptpad
## From webmail
We assume the keys have been unlocked
1. Plugin derivate the Crytpad secret with HMAC key
2. Plugin send encrypted secret to server
3. Plugin send to pad iframe key + metadata of account (mail, color) used for UI in Cryptpad
4. iframe pad open iframe sand to send metadata. Indeed, UI is avaialble only in sand domain.
5. Redirect to pad.domain/login?from=aurion
6. `ssoauth.js` page load secret and decrypt
7. user is redirected to /drive
8. `pre-loading.js` remove IndexedDB key data (TODO : move to `ssoauth.js`)
9. `drive/inner.js` load metada to show UI