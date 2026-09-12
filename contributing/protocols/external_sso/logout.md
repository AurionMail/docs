# Logout (E3) (Planned)
## Context
This operation happen when user want to logout, from Webmail or Cryptpad or from an external app from external SSO.
## Modules involved
- logout page of SSO
- Aurion Plugin
- Cryptpad
- webmail iframe
- pad iframe
## States
### Asked from Webmail or Cryptpad
1. Redirect to page `logout` SSO page
2. User confirm logout
3. message `LOGOUT_ASKED` is sent to webmail iframe and pad iframe.
4. These iframe try to send message to tabs with origin `pad` and `web` to ask for logout. For cyrptpad, it is `pre-loading.js` file which create a listener for that event. If receveied, it forward event to `pre-loading.js` of sand, which will simulate a click on logout button of Cryptpad. For the webmail, it is the plugin which listen for that event and active logout because we have already wrote `logoutAsked`. (TODO: maybe there is no need to do that)
5. if tabs are opened, they are deconnected gracefully with built-in logout. On the contrary, we remove from their localtorage auth cookies. (TODO : remove Aurion IndexedDB as well)
### Asked from external App
1. the app ask the logout to https://external-sso.domain.org/oauth/logout
2. This url is captured by http server rule to redirect to https://external-sso.domain.org/oauth/logout which will redirect to SSO logout page
3. steps from `Asked from Webmail or Cryptpad`
4. User is redirect to logout page of external SSO provider with a parameter : https://external-sso.domain.org/oauth/logout?force=true. This way, the URL is not captured