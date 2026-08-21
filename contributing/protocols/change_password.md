# Change password (P5)
## Context
This operation happen when user want to logout all, from Webmail or Cryptpad
## Modules involved
- logout page of SSO
- Aurion Plugin
- Cryptpad
- webmail iframe
- pad iframe
## States
### Asked from Webmail
This operation can only be asked from webmail.
1. User change password of its master key in Aurion Plugin
2. Aurion Plugin send the request to aurion API to change password with the old and new derived password. This will be repercuted to LDAP. At this stage, password of its master key and auth password is changed
3. Plugin generate and send 3 secret to `pad` iframe, with instrcion `CHANGE_PASSWORD` :
    2 secrets with old derived password
    1 secret with new derived password
    `changePasswordRequired` is written in indexeDB
4. Plugin  redirect to `\login`. Indeed, we can't redirect to `settings` page because it can be accessed as guest user, so we must make sure the user is connected. The fisrt secret with old password may be consumed if user is not connected. 
5. On drive page, `changePasswordRequired` is detected and user is redirected to `settings` page.
6. On settings page, the we simulate the user entring old and new password.
