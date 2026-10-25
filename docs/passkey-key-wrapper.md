# Credential-local backup-key wrapper v1

`PasskeyBackupCredentialKeyWrapper` is a disabled local cryptographic primitive shared with Android. It wraps an existing random 32-byte backup key with one 32-byte native WebAuthn PRF result. It does not implement a native PRF ceremony, verify a credential, establish ownership, authorize enrollment, enforce the latest key epoch, or enable backup/recovery. The current recoverable-key and owner-authorization defaults remain unavailable.

All lengths and integers below use the shared signed 32-bit or 64-bit big-endian format, restricted to validated nonnegative values. Strings use their exact UTF-8 bytes, each prefixed by a four-byte byte count. No JSON or locale formatting participates. The context is bounded to 4,096 bytes.

Context bytes, in order:

1. ASCII `FPBKWRAP1`, four-byte format version `1`.
2. Length-prefixed `fearlesswallet.io`, stable owner subject, storage key, wallet ID, and original account name.
3. Eight-byte creation time in milliseconds, four-byte envelope schema version `1`.
4. Length-prefixed credential ID and eight-byte key epoch.

The owner subject is `owner:` followed by canonical unpadded base64url for 32 bytes. The credential ID is canonical unpadded base64url for 1–384 bytes. Key epoch is in `0...Int64.max`. Envelope metadata uses the existing validated FPBKAEAD metadata, preserving the original account name rather than substituting a newly selected Google email.

The wrapping key is HKDF-SHA256 with the 32-byte PRF output as input key material, a fresh 32-byte HKDF salt, and info `ASCII("FPBK-PRF-KEK-v1") || context || prfSalt`. Output length is 32 bytes. The 32-byte PRF salt is public input for the credential's native PRF evaluation. This primitive accepts the resulting PRF bytes; it never substitutes credential IDs, Google identity, an assertion signature or a device-local key for PRF output.

Credential creation does not guarantee PRF output: the [WebAuthn PRF specification](https://www.w3.org/TR/webauthn-3/#prf-extension) allows an authenticator to omit it at creation. Enrollment must remain incomplete until a verified assertion for the same credential and expected PRF salt supplies the required local 32-byte result. The primitive rejects absent or incorrectly sized PRF bytes; it does not yet implement that assertion or enrollment state machine.

AES-256-GCM encrypts the 32-byte backup key with a fresh 12-byte nonce. AAD is `ASCII("FPBK-WRAP-AAD-v1") || context || prfSalt || hkdfSalt`. Ciphertext plus the 16-byte tag is exactly 48 bytes. Production salts/nonces use `SecRandomCopyBytes`; failure never falls back to deterministic data. Explicit-parameter entry points exist for fixed cross-platform tests.

The opaque record is `ASCII("FPBKWRP1") || i32(1) || i32(contextLength) || context || prfSalt[32] || hkdfSalt[32] || nonce[12] || ciphertextAndTag[48]`. No trailing bytes or alternate versions are accepted. Decode requires the exact expected context from the separately verified owner/credential/backup manifest and compares its bytes before admitting the record. Decode alone does not authenticate the ciphertext; unwrap must succeed before a recovered key is used. The encoded record contains public metadata and ciphertext, never plaintext backup keys or PRF output.

The deterministic Android/Node/iOS fixture uses PRF salt `33` repeated 32 bytes, HKDF salt `44` repeated 32 bytes, nonce `55` repeated 12 bytes, PRF output `66` repeated 32 bytes, and backup key `77` repeated 32 bytes (hexadecimal, synthetic only). Context length is 204 bytes with SHA-256 `8904743b6310afddbf7dec05ae3a4f6d1de438a0a51847eb598e5fe55bce93e3`. The encoded record is 344 bytes with SHA-256 `2ac784e30e93efb4a7fe2505724e1c67ae6f4f16e9aa834029e0bb08c27509dc`. Complete fixture inputs and intermediate HKDF/AAD assertions are in `PasskeyBackupCredentialKeyWrapperTests.swift` and the matching Android tests.

The record is not yet integrated into Drive metadata, a generation manifest or enrollment. A stale but valid context remains cryptographically valid if a caller incorrectly trusts it; rejecting rollback requires the owner/lifecycle authority and durable generation policy. Native PRF availability, cross-device key migration, successful local decryption before enrollment, final-credential removal/key rotation, and lost-device recovery still need implementation and independent device acceptance.

Secret input/output buffers remain the caller's responsibility. The wrapper stores no PRF result or plaintext key in its instance or record, uses CryptoKit `SymmetricKey` for intermediate keys, and redacts descriptions. This does not claim guaranteed erasure of all Swift/runtime copies or substitute for native secret-lifetime and crash/log-leak testing.

Apple APIs: [HKDF key derivation](https://developer.apple.com/documentation/cryptokit/hkdf/derivekey(inputkeymaterial:salt:info:outputbytecount:)), [AES-GCM](https://developer.apple.com/documentation/cryptokit/aes/gcm), [secure random bytes](https://developer.apple.com/documentation/security/secrandomcopybytes(_:_:_:)).
