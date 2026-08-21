# Login (P4)
## Context
This operation happen when user want to logout all, from Webmail or Cryptpad
## Modules involved
- logout page of SSO
- Aurion Plugin
- Cryptpad
- webmail iframe
- pad iframe
## States
### Asked from Cryptpad
1. `drive/inner.js` simulate a click on logout all button
2. At the end of the operation, Cryptpad redirect to SSO logout All page with `common-ui-elements.js` (L2356)
3. SSO logout All page get the Aurion Token from indexedb. It has been place when login. It use it to invalidate all Aurion token
4. The SSO server invalidate all Hydra tokens
5. User is redirected to SSO logout confirmed page. At this stage, the webmail sessions is not disconected. It will be soon when the duration of Hydra token is expired (5min) or when refreshing the webmail page. We need to wait for Stalwart to invalidate token.
### Asked from webmail
1. Plugin open an iframe to pad to send logoutAll: true.
2. `pad` iframe snd to `sand` iframe.
2. Plugin redirect to Cryptpad
3. `drive/inner.js` detect the logouAll data and simuate a click on logoutAll button.
4. Steps 2 to 5 of precedent paragraph