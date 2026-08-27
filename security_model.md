# AurionMail Security Model

## Threat Model & Limitations
### Web Delivery
AurionMail implements a **Client-Side Encryption with Trusted Delivery Operator** threat model. This is the threat model implemented by Cryptpad, in facts. So now, we don't need to make a better model because the entire system's security bound aligns with its weakest component.

While all sensitive operations occur strictly in the client's RAM, delivering the application bundle via a standard web browser introduces an inherent dependency on the delivery channel : In a standard browser environment, the client must trust the server not to serve malicious JavaScript. A fully compromised server could alter the front-end code to intercept input before derivation.

Rather than claiming absolute Zero-Trust, which is technically unachievable in pure web environments without local client-side verification or web extentions, AurionMail guarantees complete protection for **data-at-rest** and **passive interception**. Compromising the database yields zero unencrypted user data.

### Offline Brute-Force & Authentication Salt
If the backend LDAP/database is compromised, an attacker gains access to the encrypted key vault, the 16-byte master salt, and the authentication hash `Argon2id(password, auth_salt)`. While domain-separated HKDF prevents the auth hash from being used directly as the vault encryption key, an attacker can perform offline GPU dictionary attacks against the Argon2id auth hash to recover the master passphrase. To eliminate targeted pre-computation, salt generation is now being transitioned to per-user cryptographically random salts. The ultimate resistance against offline cracking relies on master passphrase entropy.
#### Roadmap : SRP Auth (not supported yet)

To enforce strict Zero-Knowledge authentication and eliminate the transmission of sensitive secrets over the network, authentication will be handled via the **SRP-6a protocol (RFC 5054)**.

##### Threat Model & Storage State

If the backend database and infrastructure are fully compromised, an attacker gains access to:

* The encrypted key vault (`AES-256-GCM`).
* The user's 16-byte cryptographically random salt.
* The SRP Verifier $v$, defined as $v = g^x \pmod N$.

Because no plaintext password or raw hash is stored on the server, an attacker cannot perform standard offline hash cracking against a traditional database dump. However, since the SRP Verifier $v$ serves as a static verification point derived from $x$, an attacker with a full database dump can perform an offline GPU dictionary attack by recalculating candidate verifiers $v_{\text{test}} = g^{x_{\text{test}}} \pmod N$.

To make this computationally infeasible, the client executes a heavy **Argon2id** derivation step to compute $x = \text{Argon2id}(\text{Passphrase}, \text{Salt})$ before constructing the SRP verifier. The ultimate resistance against offline cracking thus relies on master passphrase entropy (e.g., enforcing 4–5 word Diceware passphrases).

```
[CLIENT]                                                   [SERVER]
  │                                                           │
  │ ─── Step 1: POST /api/auth/srp/init { username, A } ────> │ (Generates 'b', computes 'B')
  │ <─── Returns { salt, B } ──────────────────────────────── │
  │                                                           │
  │ (Computes Argon2id, Shared Secret S, & Proof M1)          │
  │ ─── Step 2: POST /api/auth/srp/verify { M1 } ───────────> │ (Computes S, verifies M1 == M1')
  │ <─── Returns { M2, encrypted_vault, JWT } ─────────────── │ (Generates M2 & Session)
  │                                                           │
  ▼                                                           ▼
(Verifies M2 & decrypts vault in RAM)

```

1. **Step 1: Ephemeral Key Exchange (`/init`)**
* **Client:** The user enters their passphrase locally. The client generates a cryptographically secure random exponent $a$ and computes its public ephemeral key $A = g^a \pmod N$. It sends `{ username, A }` to the server.
* **Server:** Retrieves the user’s `Salt` and SRP Verifier $v$ from the database. It generates its own random exponent $b$, computes its public ephemeral key $B = (k \cdot v + g^b) \pmod N$, stores the temporary login state in ephemeral RAM (Redis/session memory), and responds with `{ salt, B }`.


2. **Step 2: Zero-Knowledge Verification (`/verify`)**
* **Client:** Derives $x = \text{Argon2id}(\text{Passphrase}, \text{Salt})$ in RAM. It then computes the scrambler $u = \text{SHA-256}(A, B)$ and the shared secret $S_{\text{client}} = (B - k \cdot g^x)^{(a + u \cdot x)} \pmod N$. From $S$, it derives the session key $K = \text{SHA-256}(S_{\text{client}})$ and generates its client authentication proof $M_1 = \text{SHA-256}(A, B, K)$. It sends $M_1$ to the server.
* **Server:** Computes $S_{\text{server}} = (A \cdot v^u)^b \pmod N$ and derives $K = \text{SHA-256}(S_{\text{server}})$. It verifies if the client's $M_1$ matches $M_1' = \text{SHA-256}(A, B, K)$.
* If valid, the server generates the server confirmation proof $M_2 = \text{SHA-256}(A, M_1, K)$, issues an HTTP session token (JWT/Cookie), and returns $\{ M_2, \text{encrypted\_vault} \}$.

##### Key Security Guarantees of this Architecture

* **Zero Secret Transmission:** The master passphrase and the derived encryption keys are never transmitted over the network in any form.
* **Replay Protection:** Ephemeral values $a$ and $b$ are generated per session, rendering intercepted $M_1$ proofs completely useless for future authentication requests.
* **State Isolation:** The server never holds the encryption key required to unlock `encrypted_vault`. Server compromise yields only ciphertext and SRP verifiers.

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