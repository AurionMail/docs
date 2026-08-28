# AurionMail Security Model

## Threat Model & Limitations
### Web Delivery
AurionMail implements a **Client-Side Encryption with Trusted Delivery Operator** threat model. This is the threat model implemented by Cryptpad, in facts. So now, we don't need to make a better model because the entire system's security bound aligns with its weakest component.

While all sensitive operations occur strictly in the client's RAM, delivering the application bundle via a standard web browser introduces an inherent dependency on the delivery channel : In a standard browser environment, the client must trust the server not to serve malicious JavaScript. A fully compromised server could alter the front-end code to intercept input before derivation.

Rather than claiming absolute Zero-Trust, which is technically unachievable in pure web environments without local client-side verification or web extentions, AurionMail guarantees complete protection for **data-at-rest** and **passive interception**. Compromising the database yields zero unencrypted user data.


### OpenPGP Limitations & Forward Secrecy
OpenPGP relies on long-term asymmetric keypairs. If a master password or private key is compromised at any point in the future, all historically archived emails encrypted with that key can be decrypted retroactively. AurionMail syncs the PGP private key (wrapped via AES-GCM) to enable seamless cross-device UX. This prioritizes multi-device usability over strict forward secrecy. Users requiring forward secrecy must manage ephemeral keys locally.

### Public Key Authenticity & Metadata
PGP over SMTP does not encrypt email envelopes (headers, timestamps, sender/recipient addresses). Encrypting to an unverified public key invalidates confidentiality guarantees. AurionMail relies on Web Key Directory (WKD) lookup to authenticate correspondent keys.

## General Concepts

In this document, a **secret** refers to any unencrypted data (such as a raw PGP private key or CryptPad seed) that could allow an administrator or attacker to decrypt user data. An **encrypted secret** requires a temporary key on user's device to be decrypted.

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

When changing the master password, the underlying persistent secrets (PGP key and CryptPad seed) are unwrapped in RAM using the old derived key and re-wrapped with the new one. Concurrently, CryptPad's native account password update procedure is triggered to update the login block, preserving all existing document keys and access without data loss.

## Auth with OPAQUE

To enforce strict Zero-Knowledge authentication and eliminate the transmission of sensitive secrets over the network, authentication is handled via the OPAQUE protocol (https://datatracker.ietf.org/doc/draft-irtf-cfrg-opaque/).

If the backend database is fully compromised, an attacker gains access to:

* The encrypted key vault (`AES-256-GCM`).
* The user's OPAQUE account record (containing the encrypted envelope and the server's OPRF public key/seed).

OPAQUE relies on an **Oblivious Pseudorandom Function**. An attacker with a full database dump **cannot** perform an offline GPU dictionary/hash cracking attack because evaluating candidate passwords requires the server's private OPRF key.

The input value passed to OPAQUE is pre-processed client-side using Argon2id with a fixed public salt (used strictly for domain isolation). If both the database and the server's private OPRF key are compromised, an offline brute-force attack becomes possible. In this scenario, the attacker must still crack the heavy Argon2id hash rather than a raw password, making entropy and Argon2id parameters the final security barrier.

The master passphrase and the derived encryption keys are never transmitted over the network in any form. This guarantees resistance to man-in-the-middle attacks.
The server never holds the encryption key required to unlock `encrypted_vault`. Server compromise yields only ciphertext and OPAQUE encrypted envelopes.