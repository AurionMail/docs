# Logout (P3)
## Context
This operation happen when user want to logout, from Webmail or Cryptpad
## Modules involved
- logout page of SSO
- Aurion Plugin
- Cryptpad
- webmail iframe
- pad iframe
## States
### Asked from Webmail or Cryptpad
1. Redirect to page `logout` SSO page (and write in localstorage `logoutAsked` for webmail)
2. User confirm logout
3. message `LOGOUT_ASKED` is sent to webmail iframe and pad iframe.
4. These iframe try to send message to tabs with origin `pad` and `web` to ask for logout. For cyrptpad, it is `pre-loading.js` file which create a listener for that event. If receveied, it forward event to `pre-loading.js` of sand, which will simulate a click on logout button of Cryptpad. For the webmail, it is the plugin which listen for that event and active logout because we have already wrote `logoutAsked`. (TODO: maybe there is no need to do that)
5. if tabs are opened, they are deconnected gracefully with built-in logout. On the contrary, we remove from their localtorage auth cookies. (TODO : remove Aurion IndexedDB as well)