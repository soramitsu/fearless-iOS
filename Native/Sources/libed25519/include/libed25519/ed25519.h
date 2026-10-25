#ifndef PROJECT_ED25519_HPP_
#define PROJECT_ED25519_HPP_

#if defined(__cplusplus)
extern "C" {
#endif

#define ed25519_pubkey_SIZE 32
#define ed25519_privkey_SIZE 32
#define ed25519_signature_SIZE 64

#ifndef ED25519_EXPORT_H
#define ED25519_EXPORT_H

#ifdef ED25519_STATIC_DEFINE
#  define ED25519_EXPORT
#  define ED25519_NO_EXPORT
#else
#  ifndef ED25519_EXPORT
#    ifdef ed25519_EXPORTS
        /* We are building this library */
#      define ED25519_EXPORT
#    else
        /* We are using this library */
#      define ED25519_EXPORT
#    endif
#  endif

#  ifndef ED25519_NO_EXPORT
#    define ED25519_NO_EXPORT
#  endif
#endif

#ifndef ED25519_DEPRECATED
#  define ED25519_DEPRECATED
#endif

#ifndef ED25519_DEPRECATED_EXPORT
#  define ED25519_DEPRECATED_EXPORT ED25519_EXPORT ED25519_DEPRECATED
#endif

#ifndef ED25519_DEPRECATED_NO_EXPORT
#  define ED25519_DEPRECATED_NO_EXPORT ED25519_NO_EXPORT ED25519_DEPRECATED
#endif

#if 0 /* DEFINE_NO_DEPRECATED */
#  ifndef ED25519_NO_DEPRECATED
#    define ED25519_NO_DEPRECATED
#  endif
#endif

#endif /* ED25519_EXPORT_H */

typedef struct {
  unsigned char data[ed25519_signature_SIZE];
} signature_t;

typedef struct {
  unsigned char data[ed25519_pubkey_SIZE];
} public_key_t;

typedef struct {
  unsigned char data[ed25519_privkey_SIZE];
} private_key_t;

/* type safe interface methods for ed25519 */

/**
 * @brief Generates a keypair. Depends on randombytes.h random generator.
 * @param[out] sk allocated buffer of ed25519_privkey_SIZE
 * @param[out] pk allocated buffer of ed25519_pubkey_SIZE
 * @return 0 if failed, non-0 otherwise
 */
ED25519_EXPORT int ed25519_create_keypair(private_key_t* sk, public_key_t* pk);

/**
 * @brief Creates a public key from given private key. For every private key
 * there is exactly one possible public key.
 *
 * Use this method to create a keypair from given randomness.
 *
 * @param[in] sk allocated buffer of ed25519_privkey_SIZE
 * @param[out] pk allocated buffer of ed25519_pubkey_SIZE
 */
ED25519_EXPORT void ed25519_derive_public_key(const private_key_t* sk,
                               public_key_t* pk);

/**
 * @brief Sign msg with keypair {pk, sk}
 * @param sig[out] signature
 * @param msg[in] message
 * @param msglen[in] message size in bytes
 * @param pk[in] public key
 * @param sk[in] secret (private) key
 */
ED25519_EXPORT void ed25519_sign(signature_t* sig, const unsigned char* msg,
                  unsigned long long msglen, const public_key_t* pk,
                  const private_key_t* sk);

/**
 * Verifies given sig over given msg with public key pk
 * @param sig[in] signature
 * @param msg[in] message
 * @param msglen[in] message size in bytes
 * @param pk[in] public key
 * @return 1 if signature is valid, 0 otherwise
 */
ED25519_EXPORT int ed25519_verify(const signature_t* sig, const unsigned char* msg,
                   unsigned long long msglen,
                   const public_key_t* pk);

#if defined(__cplusplus)
}
#endif

#endif  //  PROJECT_ED25519_HPP_
