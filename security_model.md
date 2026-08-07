# AurionMail Security
## General
In this document, a "secret" is defined as something that could be used to decrypt user data by an admin. It can be the unencrypted PGP key or Cryptpad User password. Encrypted secrets are secrets that require (directly or not) the main password to be used to decrypt user data.
### Scope
This is in Aurion Scope
- encrypt/decrypt emails with PGP in Bulwarkmail
- generate and share with Cryptpad the user encryption secret
- enable users to generate their main password used to decrypt their keys and derivate the cryptpad secret

This is **not** in Aurion Scope
- Cryptap secret management. Once the secret given to cryptpad, this is anymore in our scope.
### Constraints
- The password used to login never leave the user device.
- The secrets never  leave the user device.
For now, this is a classic Zero-Knowledge architecture. However, we add one final constraint :
- The user has only one password to remember.
- By default, the secrets never leave the RAM of user device. It means that a secret is never written on disk.
- User should type their password only once per session maximum.
## Sharing secrets
We explain here the way we share secrets between a parent (P) and a child (C) (SSO, Bulwark, Cryptpad), respecting the previous constraints.
### Steps
1. P has a secret in RAM
2. P generates a random seed and iv
3. P use this values to generate a non extractible CryptoKey
4. P encrypt the secret with the CryptoKey
5. P sends to server the encrypted secret. It receives the secret ID
6. P write in indexedDB of C the iv, seed and secret ID
7. C generate the CryptoKey from iv and seed and fetch secret from server. 
8. In RAM, C decrypt the secret with the CryptoKey
### Server's Side
The secrets are not stored in the database. They are kept in memory for 5min max. Normally, secrets should be freched during this time. If not, the secret is deleted.
### How do we write in indexedDB in step 6 ?
We use iframes to communicate between origins. Each time, the origin of sender is checked.
### Consequences
- If someone wants to get the secret, it must access at same time the Disk of user and the RAM of Server.
- If the user doesn't finish the sharing secret process, the secret is removed and local crypto is therefore useless. 
## Main password 
Once a account is created on LDAP, user must change its password on the SSO portal. If not changed, the user can't login.
The real password used for auth is the argon2id derivation of the typed password, salt with the user's username `auth_salt_${username}`.
## PGP key
The PGP key is generated in Bulwark and encrypted with the argon2id derivation of user main password and a random salt generated when we generated the key. This new passphrase is used to encrypt the key in server and user local storage. 
At same time, we generated an AES key with the main password and another random salt which is used to encrypt local search index and mails preview. 
## Cryptpad secret
To get the Cryptpad secret, we simply encrypt an hardcoded salt `cryptpad-plugin` with the generated AES key.


## Main Password & Authentication
When an account is created in LDAP, the user must change their password on the SSO portal before logging in.
The authentication payload sent to the server is an Argon2id hash derived from the user's typed password and salted with `auth_salt_${username}`.

## Key Derivation & PGP Storage

### Key Derivation Strategy
Upon account unlock or key import, a single Argon2id execution processes the user's passphrase and a 16-byte random salt to generate a **Master HKDF Key**.

Using **HKDF** (`SHA-256`), domain-isolated sub-keys are instantly derived without re-executing Argon2id:
- **PGP Wrapping Key** (`info: "pgp-wrapping-key"`): An AES-GCM 256-bit key used to encrypt the OpenPGP private key at rest (in IndexedDB or server storage).
- **Local Index + Secret AES Key** (`info: "aes-key"`): An AES-GCM 256-bit key used to encrypt local mail previews, search indexes and provide secret such as cryptpad.

## Cryptpad Secret
To eliminate Known-Plaintext Attack (KPA) vectors and avoid storing any Cryptpad seed on disk:
The Cryptpad secret is generated on the fly by encrypting a fixed static string (`plugin-cryptpad`) with the user's session AES key (`aesKey`), then hashing the output with `SHA-256`. Because the session key is unique per user, the resulting 256-bit secret is deterministic for the user but unpredictable to external attackers. No extra files or seeds are saved to IndexedDB or the server database.