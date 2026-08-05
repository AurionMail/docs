// SPDX-FileCopyrightText: 2023 XWiki CryptPad Team <contact@cryptpad.org> and contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

//const fs = require('node:fs');
module.exports = {
    enabled: true,
    enforced: true,
    cpPassword: true,
    forceCpPassword: true,
    list: [
   {
        name: 'Aurion SSO',
        type: 'oidc',
        url: 'https://oauth.DOMAIN',
        client_id: 'cryptpad',
        client_secret: 'SECRET_CRYPTPAD_SSO',
        jwt_alg: 'RS256',
        userinfo: false,
        username_claim: 'sub'
}
    ]
};