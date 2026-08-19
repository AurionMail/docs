# AurionMail Security Model
## General Concepts

In this document, a **secret** refers to any unencrypted data (such as a raw PGP private key or CryptPad seed) that could allow an administrator or attacker to decrypt user data. An **encrypted secret** requires the user's master password (or a key derived from it) to be decrypted.

### Scope

**In Scope for AurionMail:**
- End-to-end encryption/decryption of emails using PGP within Bulwark Webmail.
- Generating and securely passing encryption secrets to CryptPad.
- Enabling user-side derivation of master encryption keys from a single master password.

**Out of Scope:**
- Internal CryptPad secret lifecycle *after* handover. Once the secret is passed to CryptPad, data protection relies on CryptPad's native Zero-Knowledge architecture.

### Security Guarantees & Constraints
- **Zero-Knowledge Password:** The login password never leaves the user's device in plaintext.
- **Zero-Knowledge Secrets:** Unencrypted secrets never leave the client device.
- **Single Password UX:** Users maintain only one master password.
- **In-Memory Operations:** Secrets are kept strictly in RAM on the client side and are never written to disk unencrypted.
- **Single Prompt:** Users enter their passphrase at most once per active session.

## Secret Sharing Protocol
To transfer secrets securely between origins—such as Parent (P, e.g., SSO) and Child (C, e.g., Bulwark or CryptPad), without violating our security constraints:
### Steps
1. **P** holds an unencrypted secret in RAM.
2. **P** generates a cryptographically secure random `seed` and initialization vector (`iv`).
3. **P** uses these parameters to generate a non-extractable `CryptoKey` (`AES-GCM`).
4. **P** encrypts the secret using the `CryptoKey`.
5. **P** transmits the encrypted secret to the server and receives a temporary `secret_id`.
6. **P** writes the `iv`, `seed`, and `secret_id` into **C**'s `IndexedDB` storage via a secure cross-origin mechanism.
7. **C** reconstructs the `CryptoKey` using the local `iv` and `seed`, then fetches the encrypted secret from the server using the `secret_id`.
8. **C** decrypts the secret in RAM using the reconstructed `CryptoKey`.

### Server-Side Ephemeral Storage
The server does not store secrets in persistent storage. Encrypted payloads are held in volatile memory with a **5-minute maximum TTL**. If a child origin does not claim the secret within 5 minutes, it is purged automatically. When a secret is retrieved, it is purged from memory (Burn-on-Read).

### Cross-Origin Communication
To write parameters into child storage (Step 6), communication is handled via embedded `iframe` elements using `postMessage`. Every incoming message explicitly validates `event.origin` against an allowed list before execution.

### Security Consequences
- To compromise a secret, an attacker must simultaneously gain access to the **user's local storage/disk** and the **server's volatile RAM** within the 5-minute window.
- Abandoning the flow midway results in server-side secret deletion, rendering localized parameters useless.

## Authentication & Key Derivation
### Main Password & Authentication
When an account is provisioned in LDAP, the user sets their password via the SSO portal. 
The authentication payload sent over the wire is an **Argon2id** hash derived client-side from the user's password using the salt format `auth_salt_${username}`.

### Key Derivation Strategy
Upon account unlock or key import, a single **Argon2id** computation processes the master passphrase along with a 16-byte random salt to yield a **Master HKDF Key**.

Using **HKDF (SHA-256)**, domain-isolated sub-keys are derived instantly without requiring repeated, computationally expensive Argon2id executions:
- **PGP Wrapping Key** (`info: "pgp-wrapping-key"`): An `AES-GCM 256-bit` key used to encrypt the OpenPGP private key at rest (in IndexedDB or server sync storage).
- **Local Index AES Key** (`info: "aes-key"`): An `AES-GCM 256-bit` key used for local mail preview encryption, search indexing.
- **Cryptpad Secret**  (`info: "hmac-key"`) An `HMAC` key used for generating Cryptpad secret.
## CryptPad Secret Generation
To eliminate Known-Plaintext Attack (KPA) vectors and avoid persisting any CryptPad seed to disk:

The CryptPad secret is derived dynamically in memory by encrypting a fixed static string (`plugin-cryptpad`) using the user's active session key (`hmacKey`). Because `hmacKey` is unique to each user session context, the derived secret is deterministic for the user while remaining unpredictable to external observers. No intermediate seeds or secret tokens are written to disk or sent to the backend database.