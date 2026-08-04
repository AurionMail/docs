# AurionMail Suite
The AurionMail Suite is a free and open-source end-to-end encrypted work suite. 

**TL;DR:** AurionMail Suite offers a Proton-like experience. It relies on proven technologies like CryptPad, Bulwark Webmail, Stalwart Mail Server, Ory Hydra, and PGP.

## The Problem
CryptPad is a powerful collaborative tool, but it doesn't include email—which is outside its scope. As a result, using encrypted documents and encrypted emails usually requires two separate accounts and passwords. 

AurionMail acts as the glue linking CryptPad and a JMAP-based email service into a seamless workflow.

## What does this mean for the user?
Users only need to remember **one single password** to encrypt and decrypt both their emails and CryptPad documents. You enter it once per session, whether you access CryptPad, the webmail, or both. Sounds like magic, doesn't it? 

Additionally, we refreshed CryptPad's UI to make it modern and sleek.
## Screenshots
Here is some screenshots to convince you.
![Login](./screenshots/login.png)
![Logout](./screenshots/logout.png)
![Keys](./screenshots/keys.png)
![Cryptpad](./screenshots/cryptpad.png)
## How ?
Here is what we use. Items in bold are what was code by Aurion Team.
- LDAP for user managment. This is the source of truth for users
- Ory Hydra for the SSO Backend. it handle the login process
- **SSO Web App for SSO fronted**. It handle the login/logout of users and is used to let users use one password to login and to decrypt their data and keeping out system 0K
- Stalwart Server : Used as a JMAP backend for the emails
- Bulwark Webmail : The Mail fronted. Alone, it doesn't handle encryption.
- **Bulwark PGP Plugin** : A Bulwark Plugin used ton encrypt emails end provide users a proton-like experience
- **Core-API** : The core server of AurionMail. It handle the sync of the keys of users, the connexion with webmail and cryptpad.
- **Bridges** : Some littles files used during login/logout to communicate with the apps to share secrets
- Cryptpad with SSO Plugin and **customized with our files** to integrate better with the webmail and provide a better UI
As you may notice, we won't provide a single binary
## Want more screenshots or just curious ?
You can go to the repos of the part you want to explore
- [SSO App](https://github.com/aurionMail/sso)
- [Bridges](https://github.com/AurionMail/bridges/)
- [PGP Plugin](https://github.com/AurionMail/bulwark-pgp-plugin)
- [Core API](https://github.com/AurionMail/core-api/)
- [Cryptpad Customized](https://github.com/AurionMail/cryptpad_customized/)
## Lets' deep in
### I am an end user
TODO
### I am a sysadmin and I want to give a try
Let's go to [Install](./install.md) to begin the journey