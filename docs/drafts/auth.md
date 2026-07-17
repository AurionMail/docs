### Conf Authelia (Base)

```yaml
authentication_backend:
  password_reset:
    disable: true
  ldap:
    implementation: 'lldap'
    address: 'ldap://127.0.0.1:3890'
    base_dn: 'dc=aurionmail,dc=org'
    additional_users_dn: 'ou=people'
    user: 'uid=admin,ou=people,dc=aurionmail,dc=org'
    password: 'essai5432'
    attributes:
      username: 'uid'
      display_name: 'displayName'
      mail: 'mail'
      member_of: 'memberOf'
      group_name: 'cn'

access_control:
  default_policy: deny
  rules:
    - domain: '*.aurionmail.org'
      policy: one_factor

session:
  secret: 'secret'
  cookies:
    - name: 'authelia_session'
      domain: 'aurionmail.org'
      authelia_url: 'https://auth.aurionmail.org'
storage:
  encryption_key: 'secret'
  local:
    path: "/var/lib/authelia/db.sqlite3"
notifier:
  disable_startup_check: false
  filesystem:
    filename: '/var/lib/authelia//notification.txt'
server:
  address: 'tcp://127.0.0.1:9091'

identity_providers:
  oidc:
    jwks:
      - key_id: 'main-key'
        algorithm: 'RS256'
        use: 'sig'
        key: |
          -----BEGIN PRIVATE KEY-----
          sDr+X9/dTHUaBk7EGRk2PCDPhcjRdZeuQO5R/NlR22cpCwexw45FY9Kr+fqm+8fD
          VhEovyL8QvEY66u1M7AB8sY=
          -----END PRIVATE KEY-----
    clients:
      - client_id: 'stalwart'
        client_name: 'Stalwart Mail'
        client_secret: 'secret'
        public: false
        authorization_policy: 'one_factor'
        redirect_uris:
          - 'https://server.mail.aurionmail.org/login/oauth2/code/authelia'
        scopes:
          - 'openid'
          - 'profile'
          - 'email'
          - 'groups'
        userinfo_signed_response_alg: 'none'
      - client_id: 'bulwark'
        client_name: 'AurionMail Webmail'
        client_secret: 'scret'
        public: false
        authorization_policy: 'one_factor'
        token_endpoint_auth_method: 'client_secret_post'
        redirect_uris:
          - 'https://officialweb.mail.aurionmail.org/auth/callback'
          - 'https://officialweb.mail.aurionmail.org/en/auth/callback'
          - 'https://officialweb.mail.aurionmail.org/fr/auth/callback'
        scopes:
          - 'openid'
          - 'profile'
          - 'email'
        userinfo_signed_response_alg: 'none'
      - client_id: 'cryptpad'
        client_name: 'Cryptad'
        client_secret: 'secret'
        public: false
        authorization_policy: 'one_factor'
        redirect_uris:
          - 'https://pad.aurionmail.org/ssoauth'
        scopes:
          - 'openid'
          - 'profile'
          - 'email'
```

### Conf Bulwark

Oauth : Y 
OAuth Only : Y
OAuthClientID: bulwark 
OAuth Client Secret : secret 
OAuth Issuer URL : https://auth.aurionmail.org
Auto SSO : Y 

### Conf Stalwart

Authentication->Directories 

Issuer URL : https://auth.aurionmail.org
Required Audience : bulwark
Required Scopes : email, openId 
Username Claim : preferred_username
Name Claim : name 
Groups Claim : groups

### Conf Cryptpad 

```javascript
// SPDX-FileCopyrightText: 2023 XWiki CryptPad Team <contact@cryptpad.org> and contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

//const fs = require('node:fs');
module.exports = {
    // Enable SSO login on this instance
    enabled: true,
    // Block registration for non-SSO users on this instance
    enforced: true,
    // Allow users to add an additional CryptPad password to their SSO account
    cpPassword: true,
    // You can also force your SSO users to add a CryptPad password
    forceCpPassword: true,
    // List of SSO providers
    list: [
    {
        name: 'authelia',
        type: 'oidc',
        url: 'https://auth.aurionmail.org',
        client_id: 'cryptpad',
        client_secret: 'secret',
        jwt_alg: 'RS256'
}
    ]
};
```