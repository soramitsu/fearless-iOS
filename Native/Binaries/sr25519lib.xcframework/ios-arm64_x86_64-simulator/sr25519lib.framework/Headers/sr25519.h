#ifndef __SR25519_INCLUDE_GUARD_H__
#define __SR25519_INCLUDE_GUARD_H__

/* Generated with cbindgen:0.29.4 */

/* THIS FILE WAS AUTOMATICALLY GENERATED. DO NOT EDIT. Ref: https://github.com/Warchant/sr25519-crust */

#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

/**
 * Size of input SEED for derivation, bytes
 */
#define SR25519_SEED_SIZE 32

/**
 * Size of CHAINCODE, bytes
 */
#define SR25519_CHAINCODE_SIZE 32

/**
 * Size of SR25519 PUBLIC KEY, bytes
 */
#define SR25519_PUBLIC_SIZE 32

/**
 * Size of SR25519 PRIVATE (SECRET) KEY, which consists of [32 bytes key | 32 bytes nonce]
 */
#define SR25519_SECRET_SIZE 64

/**
 * Size of SR25519 SIGNATURE, bytes
 */
#define SR25519_SIGNATURE_SIZE 64

/**
 * Size of SR25519 KEYPAIR. [32 bytes key | 32 bytes nonce | 32 bytes public]
 */
#define SR25519_KEYPAIR_SIZE 96

/**
 * Size of VRF output, bytes
 */
#define SR25519_VRF_OUTPUT_SIZE 32

/**
 * Size of VRF proof, bytes
 */
#define SR25519_VRF_PROOF_SIZE 64

/**
 * Size of VRF raw output, bytes
 */
#define SR25519_VRF_RAW_OUTPUT_SIZE 16

/**
 * Size of VRF limit, bytes
 */
#define SR25519_VRF_THRESHOLD_SIZE 16

/**
 * Checked signing result. The existing `sr25519_sign` ABI remains unchanged.
 */
typedef enum Sr25519SignResult {
  Sr25519SignOk = 0,
  Sr25519SignInvalidArgument = 1,
  Sr25519SignInvalidSecret = 2,
  Sr25519SignInvalidPublic = 3,
  Sr25519SignMismatchedKeypair = 4,
  Sr25519SignInternalError = 5,
} Sr25519SignResult;

typedef enum Sr25519SignatureResult {
  Ok,
  EquationFalse,
  PointDecompressionError,
  ScalarFormatError,
  BytesLengthError,
  NotMarkedSchnorrkel,
  MuSigAbsent,
  MuSigInconsistent,
} Sr25519SignatureResult;

typedef struct VrfResult {
  enum Sr25519SignatureResult result;
  bool is_less;
} VrfResult;

/**
 * Convert an expanded Ed25519 secret into the SR25519 secret representation.
 * This legacy export is present in the original wallet binary.
 */
void sr25519_from_ed25519_bytes(uint8_t *secret_out,
                                const uint8_t *secret_ptr);

/**
 * Convert an SR25519 secret into the expanded Ed25519 representation.
 * This legacy export is present in the original wallet binary.
 */
void sr25519_to_ed25519_bytes(uint8_t *secret_out,
                              const uint8_t *secret_ptr);

/**
 * Perform a derivation on a secret
 *
 * * keypair_out: pre-allocated output buffer of SR25519_KEYPAIR_SIZE bytes
 * * pair_ptr: existing keypair - input buffer of SR25519_KEYPAIR_SIZE bytes
 * * cc_ptr: chaincode - input buffer of SR25519_CHAINCODE_SIZE bytes
 *
 */
void sr25519_derive_keypair_hard(uint8_t *keypair_out,
                                 const uint8_t *pair_ptr,
                                 const uint8_t *cc_ptr);

/**
 * Perform a derivation on a secret
 *
 * * keypair_out: pre-allocated output buffer of SR25519_KEYPAIR_SIZE bytes
 * * pair_ptr: existing keypair - input buffer of SR25519_KEYPAIR_SIZE bytes
 * * cc_ptr: chaincode - input buffer of SR25519_CHAINCODE_SIZE bytes
 *
 */
void sr25519_derive_keypair_soft(uint8_t *keypair_out,
                                 const uint8_t *pair_ptr,
                                 const uint8_t *cc_ptr);

/**
 * Perform a derivation on a publicKey
 *
 * * pubkey_out: pre-allocated output buffer of SR25519_PUBLIC_SIZE bytes
 * * public_ptr: public key - input buffer of SR25519_PUBLIC_SIZE bytes
 * * cc_ptr: chaincode - input buffer of SR25519_CHAINCODE_SIZE bytes
 *
 */
void sr25519_derive_public_soft(uint8_t *pubkey_out,
                                const uint8_t *public_ptr,
                                const uint8_t *cc_ptr);

/**
 * Generate a key pair.
 *
 * * keypair_out: keypair [32b key | 32b nonce | 32b public], pre-allocated output buffer of SR25519_KEYPAIR_SIZE bytes
 * * seed: generation seed - input buffer of SR25519_SEED_SIZE bytes
 *
 */
void sr25519_keypair_from_seed(uint8_t *keypair_out,
                               const uint8_t *seed_ptr);

/**
 * Sign a message
 *
 * The combination of both public and private key must be provided.
 * This is effectively equivalent to a keypair.
 *
 * * signature_out: output buffer of ED25519_SIGNATURE_SIZE bytes
 * * public_ptr: public key - input buffer of SR25519_PUBLIC_SIZE bytes
 * * secret_ptr: private key (secret) - input buffer of SR25519_SECRET_SIZE bytes
 * * message_ptr: Arbitrary message; input buffer of size message_length
 * * message_length: Length of a message
 *
 */
void sr25519_sign(uint8_t *signature_out,
                  const uint8_t *public_ptr,
                  const uint8_t *secret_ptr,
                  const uint8_t *message_ptr,
                  unsigned long message_length);

/**
 * Sign without unwinding through the C ABI. Every buffer size is explicit.
 * `message_ptr` may be null only when `message_length` is zero. On failure,
 * the first SR25519_SIGNATURE_SIZE bytes of a valid output buffer are zeroed.
 */
enum Sr25519SignResult sr25519_sign_checked(uint8_t *signature_out,
                                            uintptr_t signature_out_length,
                                            const uint8_t *public_ptr,
                                            uintptr_t public_length,
                                            const uint8_t *secret_ptr,
                                            uintptr_t secret_length,
                                            const uint8_t *message_ptr,
                                            uintptr_t message_length);

/**
 * Verify a message and its corresponding against a public key;
 *
 * * signature_ptr: verify this signature
 * * message_ptr: Arbitrary message; input buffer of message_length bytes
 * * message_length: Message size
 * * public_ptr: verify with this public key; input buffer of SR25519_PUBLIC_SIZE bytes
 *
 * * returned true if signature is valid, false otherwise
 */
bool sr25519_verify(const uint8_t *signature_ptr,
                    const uint8_t *message_ptr,
                    unsigned long message_length,
                    const uint8_t *public_ptr);

/**
 * Sign the provided message using a Verifiable Random Function and
 * if the result is less than \param limit provide the proof
 * @param out_and_proof_ptr pointer to output array, where the VRF out and proof will be written
 * @param keypair_ptr byte representation of the keypair that will be used during signing
 * @param message_ptr byte array to be signed
 * @param limit_ptr byte array, must be 16 bytes long
 *
 */
struct VrfResult sr25519_vrf_sign_if_less(uint8_t *out_and_proof_ptr,
                                          const uint8_t *keypair_ptr,
                                          const uint8_t *message_ptr,
                                          unsigned long message_length,
                                          const uint8_t *limit_ptr);

/**
 * Verify a signature produced by a VRF with its original input and the corresponding proof and
 * check if the result of the function is less than the threshold.
 * @note If errors, is_less field of the returned structure is not meant to contain a valid value
 * @param public_key_ptr byte representation of the public key that was used to sign the message
 * @param message_ptr the orignal signed message
 * @param output_ptr the signature
 * @param proof_ptr the proof of the signature
 * @param threshold_ptr the threshold to be compared against
 */
struct VrfResult sr25519_vrf_verify(const uint8_t *public_key_ptr,
                                    const uint8_t *message_ptr,
                                    unsigned long message_length,
                                    const uint8_t *output_ptr,
                                    const uint8_t *proof_ptr,
                                    const uint8_t *threshold_ptr);

#endif  /* __SR25519_INCLUDE_GUARD_H__ */
