// for enum variants
#![allow(unused_variables)]
#![allow(non_snake_case)]

extern crate schnorrkel;

// Copyright 2019 Soramitsu via https://github.com/Warchant/sr25519-crust
// Copyright 2019 Paritytech via https://github.com/paritytech/schnorrkel-js/
// Copyright 2019 @polkadot/wasm-schnorrkel authors & contributors
// This software may be modified and distributed under the terms
// of the Apache-2.0 license. See the LICENSE file for details.

// Originally developed (as a fork) in https://github.com/polkadot-js/schnorrkel-js/
// which was adopted from the initial https://github.com/paritytech/schnorrkel-js/
// forked at commit eff430ddc3090f56317c80654208b8298ef7ab3f

use std::os::raw::c_ulong;
use std::ptr;
use std::slice;

use schnorrkel::{
    context::signing_context,
    derive::{CHAIN_CODE_LENGTH, ChainCode, Derivation}, ExpansionMode, Keypair, MiniSecretKey, PublicKey,
    SecretKey, Signature, SignatureError, vrf::{VRFPreOut, VRFProof}};
use std::fmt::{Formatter, Error};

// cbindgen has an issue with macros, so define it outside,
// otherwise it would've been possible to avoid duplication of macro variant list
#[repr(C)]
#[derive(Clone, Copy, Debug, Eq, PartialEq, Hash)]
pub enum Sr25519SignatureResult {
    Ok,
    EquationFalse,
    PointDecompressionError,
    ScalarFormatError,
    BytesLengthError,
    NotMarkedSchnorrkel,
    MuSigAbsent,
    MuSigInconsistent,
}

/// converts from schnorrkel::SignatureError
/// to Sr25519SignatureResult (which is exported to C header)
fn convert_error(err: &SignatureError) -> Sr25519SignatureResult {
    match err {
        SignatureError::EquationFalse => Sr25519SignatureResult::EquationFalse,
        // Preserve the legacy C enum layout while rejecting invalid public keys.
        SignatureError::InvalidKey => Sr25519SignatureResult::EquationFalse,
        SignatureError::PointDecompressionError => Sr25519SignatureResult::PointDecompressionError,
        SignatureError::ScalarFormatError => Sr25519SignatureResult::ScalarFormatError,
        SignatureError::BytesLengthError { name: _, description: _, length: _ }
        => Sr25519SignatureResult::BytesLengthError,
        SignatureError::MuSigAbsent { musig_stage: _ } => Sr25519SignatureResult::MuSigAbsent,
        SignatureError::MuSigInconsistent { musig_stage: _, duplicate: _ }
        => Sr25519SignatureResult::MuSigInconsistent,
        SignatureError::NotMarkedSchnorrkel => Sr25519SignatureResult::NotMarkedSchnorrkel
    }
}

// We must make sure that this is the same as declared in the substrate source code.
const SIGNING_CTX: &'static [u8] = b"substrate";
pub const BABE_VRF_PREFIX: &'static [u8] = b"substrate-babe-vrf";

/// ChainCode construction helper
fn create_cc(data: &[u8]) -> ChainCode {
    let mut cc = [0u8; CHAIN_CODE_LENGTH];

    cc.copy_from_slice(&data);

    ChainCode(cc)
}

/// Keypair helper function.
fn create_from_seed(seed: &[u8]) -> Keypair {
    match MiniSecretKey::from_bytes(seed) {
        Ok(mini) => return mini.expand_to_keypair(ExpansionMode::Ed25519),
        Err(_) => panic!("Provided seed is invalid."),
    }
}

/// Keypair helper function.
fn create_from_pair(pair: &[u8]) -> Keypair {
    match Keypair::from_bytes(pair) {
        Ok(pair) => return pair,
        Err(_) => panic!(format!("Provided pair is invalid: {:?}", pair)),
    }
}

/// PublicKey helper
fn create_public(public: &[u8]) -> PublicKey {
    match PublicKey::from_bytes(public) {
        Ok(public) => return public,
        Err(_) => panic!("Provided public key is invalid."),
    }
}

/// SecretKey helper
fn create_secret(secret: &[u8]) -> SecretKey {
    match SecretKey::from_bytes(secret) {
        Ok(secret) => return secret,
        Err(_) => panic!("Provided private key is invalid."),
    }
}

/// Size of input SEED for derivation, bytes
pub const SR25519_SEED_SIZE: c_ulong = 32;

/// Size of CHAINCODE, bytes
pub const SR25519_CHAINCODE_SIZE: c_ulong = 32;

/// Size of SR25519 PUBLIC KEY, bytes
pub const SR25519_PUBLIC_SIZE: c_ulong = 32;

/// Size of SR25519 PRIVATE (SECRET) KEY, which consists of [32 bytes key | 32 bytes nonce]
pub const SR25519_SECRET_SIZE: c_ulong = 64;

/// Size of SR25519 SIGNATURE, bytes
pub const SR25519_SIGNATURE_SIZE: c_ulong = 64;

/// Size of SR25519 KEYPAIR. [32 bytes key | 32 bytes nonce | 32 bytes public]
pub const SR25519_KEYPAIR_SIZE: c_ulong = 96;

/// Size of VRF output, bytes
pub const SR25519_VRF_OUTPUT_SIZE: c_ulong = 32;

/// Size of VRF proof, bytes
pub const SR25519_VRF_PROOF_SIZE: c_ulong = 64;

/// Size of VRF raw output, bytes
pub const SR25519_VRF_RAW_OUTPUT_SIZE: c_ulong = 16;

/// Size of VRF limit, bytes
pub const SR25519_VRF_THRESHOLD_SIZE: c_ulong = 16;

/// Convert an expanded Ed25519 secret into the SR25519 secret representation.
/// This legacy export is present in the original wallet binary.
#[no_mangle]
pub unsafe extern "C" fn sr25519_from_ed25519_bytes(
    secret_out: *mut u8,
    secret_ptr: *const u8,
) {
    let secret = slice::from_raw_parts(secret_ptr, SR25519_SECRET_SIZE as usize);
    let converted = SecretKey::from_ed25519_bytes(secret)
        .expect("Provided Ed25519 private key is invalid.")
        .to_bytes();
    ptr::copy_nonoverlapping(converted.as_ptr(), secret_out, SR25519_SECRET_SIZE as usize);
}

/// Convert an SR25519 secret into the expanded Ed25519 representation.
/// This legacy export is present in the original wallet binary.
#[no_mangle]
pub unsafe extern "C" fn sr25519_to_ed25519_bytes(
    secret_out: *mut u8,
    secret_ptr: *const u8,
) {
    let secret = slice::from_raw_parts(secret_ptr, SR25519_SECRET_SIZE as usize);
    let converted = create_secret(secret).to_ed25519_bytes();
    ptr::copy_nonoverlapping(converted.as_ptr(), secret_out, SR25519_SECRET_SIZE as usize);
}

/// Perform a derivation on a secret
///
/// * keypair_out: pre-allocated output buffer of SR25519_KEYPAIR_SIZE bytes
/// * pair_ptr: existing keypair - input buffer of SR25519_KEYPAIR_SIZE bytes
/// * cc_ptr: chaincode - input buffer of SR25519_CHAINCODE_SIZE bytes
///
#[allow(unused_attributes)]
#[no_mangle]
pub unsafe extern "C" fn sr25519_derive_keypair_hard(
    keypair_out: *mut u8,
    pair_ptr: *const u8,
    cc_ptr: *const u8,
) {
    let pair = slice::from_raw_parts(pair_ptr, SR25519_KEYPAIR_SIZE as usize);
    let cc = slice::from_raw_parts(cc_ptr, SR25519_CHAINCODE_SIZE as usize);
    let kp = create_from_pair(pair)
        .secret
        .hard_derive_mini_secret_key(Some(create_cc(cc)), &[])
        .0
        .expand_to_keypair(ExpansionMode::Ed25519);

    ptr::copy(kp.to_bytes().as_ptr(), keypair_out, SR25519_KEYPAIR_SIZE as usize);
}

/// Perform a derivation on a secret
///
/// * keypair_out: pre-allocated output buffer of SR25519_KEYPAIR_SIZE bytes
/// * pair_ptr: existing keypair - input buffer of SR25519_KEYPAIR_SIZE bytes
/// * cc_ptr: chaincode - input buffer of SR25519_CHAINCODE_SIZE bytes
///
#[allow(unused_attributes)]
#[no_mangle]
pub unsafe extern "C" fn sr25519_derive_keypair_soft(
    keypair_out: *mut u8,
    pair_ptr: *const u8,
    cc_ptr: *const u8,
) {
    let pair = slice::from_raw_parts(pair_ptr, SR25519_KEYPAIR_SIZE as usize);
    let cc = slice::from_raw_parts(cc_ptr, SR25519_CHAINCODE_SIZE as usize);
    let kp = create_from_pair(pair)
        .derived_key_simple(create_cc(cc), &[])
        .0;

    ptr::copy(kp.to_bytes().as_ptr(), keypair_out, SR25519_KEYPAIR_SIZE as usize);
}

/// Perform a derivation on a publicKey
///
/// * pubkey_out: pre-allocated output buffer of SR25519_PUBLIC_SIZE bytes
/// * public_ptr: public key - input buffer of SR25519_PUBLIC_SIZE bytes
/// * cc_ptr: chaincode - input buffer of SR25519_CHAINCODE_SIZE bytes
///
#[allow(unused_attributes)]
#[no_mangle]
pub unsafe extern "C" fn sr25519_derive_public_soft(
    pubkey_out: *mut u8,
    public_ptr: *const u8,
    cc_ptr: *const u8,
) {
    let public = slice::from_raw_parts(public_ptr, SR25519_PUBLIC_SIZE as usize);
    let cc = slice::from_raw_parts(cc_ptr, SR25519_CHAINCODE_SIZE as usize);
    let p = create_public(public)
        .derived_key_simple(create_cc(cc), &[])
        .0;
    ptr::copy(p.to_bytes().as_ptr(), pubkey_out, SR25519_PUBLIC_SIZE as usize);
}

/// Generate a key pair.
///
/// * keypair_out: keypair [32b key | 32b nonce | 32b public], pre-allocated output buffer of SR25519_KEYPAIR_SIZE bytes
/// * seed: generation seed - input buffer of SR25519_SEED_SIZE bytes
///
#[allow(unused_attributes)]
#[no_mangle]
pub unsafe extern "C" fn sr25519_keypair_from_seed(keypair_out: *mut u8, seed_ptr: *const u8) {
    let seed = slice::from_raw_parts(seed_ptr, SR25519_SEED_SIZE as usize);
    let kp = create_from_seed(seed);
    ptr::copy(kp.to_bytes().as_ptr(), keypair_out, SR25519_KEYPAIR_SIZE as usize);
}

/// Sign a message
///
/// The combination of both public and private key must be provided.
/// This is effectively equivalent to a keypair.
///
/// * signature_out: output buffer of ED25519_SIGNATURE_SIZE bytes
/// * public_ptr: public key - input buffer of SR25519_PUBLIC_SIZE bytes
/// * secret_ptr: private key (secret) - input buffer of SR25519_SECRET_SIZE bytes
/// * message_ptr: Arbitrary message; input buffer of size message_length
/// * message_length: Length of a message
///
#[allow(unused_attributes)]
#[no_mangle]
pub unsafe extern "C" fn sr25519_sign(
    signature_out: *mut u8,
    public_ptr: *const u8,
    secret_ptr: *const u8,
    message_ptr: *const u8,
    message_length: c_ulong,
) {
    let public = slice::from_raw_parts(public_ptr, SR25519_PUBLIC_SIZE as usize);
    let secret = slice::from_raw_parts(secret_ptr, SR25519_SECRET_SIZE as usize);
    let message = slice::from_raw_parts(message_ptr, message_length as usize);

    let sig = create_secret(secret).sign_simple(SIGNING_CTX, message, &create_public(public));

    ptr::copy(
        sig.to_bytes().as_ptr(),
        signature_out,
        SR25519_SIGNATURE_SIZE as usize,
    );
}

/// Checked signing result. The existing `sr25519_sign` ABI remains unchanged.
#[repr(C)]
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum Sr25519SignResult {
    Sr25519SignOk = 0,
    Sr25519SignInvalidArgument = 1,
    Sr25519SignInvalidSecret = 2,
    Sr25519SignInvalidPublic = 3,
    Sr25519SignMismatchedKeypair = 4,
    Sr25519SignInternalError = 5,
}

/// Sign without unwinding through the C ABI. Every buffer size is explicit.
/// `message_ptr` may be null only when `message_length` is zero. On failure,
/// the first SR25519_SIGNATURE_SIZE bytes of a valid output buffer are zeroed.
#[no_mangle]
pub unsafe extern "C" fn sr25519_sign_checked(
    signature_out: *mut u8,
    signature_out_length: usize,
    public_ptr: *const u8,
    public_length: usize,
    secret_ptr: *const u8,
    secret_length: usize,
    message_ptr: *const u8,
    message_length: usize,
) -> Sr25519SignResult {
    let signature_length = SR25519_SIGNATURE_SIZE as usize;
    if signature_out.is_null() || signature_out_length < signature_length {
        return Sr25519SignResult::Sr25519SignInvalidArgument;
    }
    ptr::write_bytes(signature_out, 0, signature_length);
    if public_ptr.is_null() || public_length != SR25519_PUBLIC_SIZE as usize
        || secret_ptr.is_null() || secret_length != SR25519_SECRET_SIZE as usize
        || (message_ptr.is_null() && message_length != 0)
    {
        return Sr25519SignResult::Sr25519SignInvalidArgument;
    }

    let sign = || {
        let public_bytes = slice::from_raw_parts(public_ptr, public_length);
        let secret_bytes = slice::from_raw_parts(secret_ptr, secret_length);
        let message = if message_length == 0 {
            &[][..]
        } else {
            slice::from_raw_parts(message_ptr, message_length)
        };
        let secret = match SecretKey::from_bytes(secret_bytes) {
            Ok(secret) => secret,
            Err(_) => return Sr25519SignResult::Sr25519SignInvalidSecret,
        };
        let public = match PublicKey::from_bytes(public_bytes) {
            Ok(public) => public,
            Err(_) => return Sr25519SignResult::Sr25519SignInvalidPublic,
        };
        if secret.to_public() != public {
            return Sr25519SignResult::Sr25519SignMismatchedKeypair;
        }

        let signature = secret.sign_simple(SIGNING_CTX, message, &public);
        ptr::copy_nonoverlapping(signature.to_bytes().as_ptr(), signature_out, signature_length);
        Sr25519SignResult::Sr25519SignOk
    };
    match std::panic::catch_unwind(std::panic::AssertUnwindSafe(sign)) {
        Ok(result) => result,
        Err(_) => {
            ptr::write_bytes(signature_out, 0, signature_length);
            Sr25519SignResult::Sr25519SignInternalError
        }
    }
}

/// Verify a message and its corresponding against a public key;
///
/// * signature_ptr: verify this signature
/// * message_ptr: Arbitrary message; input buffer of message_length bytes
/// * message_length: Message size
/// * public_ptr: verify with this public key; input buffer of SR25519_PUBLIC_SIZE bytes
///
/// * returned true if signature is valid, false otherwise
#[allow(unused_attributes)]
#[no_mangle]
pub unsafe extern "C" fn sr25519_verify(
    signature_ptr: *const u8,
    message_ptr: *const u8,
    message_length: c_ulong,
    public_ptr: *const u8,
) -> bool {
    let public = slice::from_raw_parts(public_ptr, SR25519_PUBLIC_SIZE as usize);
    let signature = slice::from_raw_parts(signature_ptr, SR25519_SIGNATURE_SIZE as usize);
    let message = slice::from_raw_parts(message_ptr, message_length as usize);
    let signature = match Signature::from_bytes(signature) {
        Ok(signature) => signature,
        Err(_) => return false,
    };

    create_public(public).verify_simple(SIGNING_CTX, message, &signature).is_ok()
}

#[repr(C)]
pub struct VrfResult {
    pub result: Sr25519SignatureResult,
    pub is_less: bool,
}

impl VrfResult {
    fn create_err(err: &SignatureError) -> VrfResult {
        VrfResult { is_less: false, result: convert_error(&err) }
    }

    fn create_val(is_less: bool) -> VrfResult {
        VrfResult { is_less, result: Sr25519SignatureResult::Ok }
    }
}

impl std::fmt::Debug for VrfResult {
    fn fmt(&self, f: &mut Formatter<'_>) -> Result<(), Error> {
        f.write_str("VrfResult { ")?;
        f.write_str(self.is_less.to_string().as_str())?;
        f.write_str(", ")?;
        write!(f, "{:?}", self)?;
        f.write_str(" }")?;
        Result::Ok(())
    }
}

/// Sign the provided message using a Verifiable Random Function and
/// if the result is less than \param limit provide the proof
/// @param out_and_proof_ptr pointer to output array, where the VRF out and proof will be written
/// @param keypair_ptr byte representation of the keypair that will be used during signing
/// @param message_ptr byte array to be signed
/// @param limit_ptr byte array, must be 16 bytes long
///
#[allow(unused_attributes)]
#[no_mangle]
pub unsafe extern "C" fn sr25519_vrf_sign_if_less(
    out_and_proof_ptr: *mut u8,
    keypair_ptr: *const u8,
    message_ptr: *const u8,
    message_length: c_ulong,
    limit_ptr: *const u8,
) -> VrfResult {
    let keypair_bytes = slice::from_raw_parts(keypair_ptr, SR25519_KEYPAIR_SIZE as usize);
    let keypair = create_from_pair(keypair_bytes);
    let message = slice::from_raw_parts(message_ptr, message_length as usize);

    let limit = slice::from_raw_parts(limit_ptr, SR25519_VRF_THRESHOLD_SIZE as usize);
    let mut limit_arr: [u8; SR25519_VRF_THRESHOLD_SIZE as usize] = Default::default();
    limit_arr.copy_from_slice(&limit[0..SR25519_VRF_THRESHOLD_SIZE as usize]);

    let (io, proof, _) =
        keypair.vrf_sign(
            signing_context(SIGNING_CTX).bytes(message));
    let limit_int = u128::from_le_bytes(limit_arr);

    let raw_out_bytes = io.make_bytes::<[u8; SR25519_VRF_RAW_OUTPUT_SIZE as usize]>(BABE_VRF_PREFIX);
    let check = u128::from_le_bytes(raw_out_bytes) < limit_int;

    ptr::copy(io.to_preout().as_bytes().as_ptr(), out_and_proof_ptr, SR25519_VRF_OUTPUT_SIZE as usize);
    ptr::copy(proof.to_bytes().as_ptr(), out_and_proof_ptr.add(SR25519_VRF_OUTPUT_SIZE as usize), SR25519_VRF_PROOF_SIZE as usize);
    if check {
        VrfResult::create_val(true)
    } else {
        VrfResult::create_val(false)
    }
}

/// Verify a signature produced by a VRF with its original input and the corresponding proof and
/// check if the result of the function is less than the threshold.
/// @note If errors, is_less field of the returned structure is not meant to contain a valid value
/// @param public_key_ptr byte representation of the public key that was used to sign the message
/// @param message_ptr the orignal signed message
/// @param output_ptr the signature
/// @param proof_ptr the proof of the signature
/// @param threshold_ptr the threshold to be compared against
#[allow(unused_attributes)]
#[no_mangle]
pub unsafe extern "C" fn sr25519_vrf_verify(
    public_key_ptr: *const u8,
    message_ptr: *const u8,
    message_length: c_ulong,
    output_ptr: *const u8,
    proof_ptr: *const u8,
    threshold_ptr: *const u8,
) -> VrfResult {
    let public_key = create_public(slice::from_raw_parts(public_key_ptr, SR25519_PUBLIC_SIZE as usize));
    let message = slice::from_raw_parts(message_ptr, message_length as usize);
    let ctx = signing_context(SIGNING_CTX).bytes(message);
    let given_out = match VRFPreOut::from_bytes(
        slice::from_raw_parts(output_ptr, SR25519_VRF_OUTPUT_SIZE as usize)) {
        Ok(val) => val,
        Err(err) => return VrfResult::create_err(&err)
    };
    let given_proof = match VRFProof::from_bytes(
        slice::from_raw_parts(proof_ptr, SR25519_VRF_PROOF_SIZE as usize)) {
        Ok(val) => val,
        Err(err) => return VrfResult::create_err(&err)
    };
    let (in_out, proof) =
        match public_key.vrf_verify(ctx.clone(), &given_out, &given_proof) {
            Ok(val) => val,
            Err(err) => return VrfResult::create_err(&err)
        };
    let raw_output = in_out.make_bytes::<[u8; SR25519_VRF_RAW_OUTPUT_SIZE as usize]>(BABE_VRF_PREFIX);

    let threshold = slice::from_raw_parts(threshold_ptr, SR25519_VRF_THRESHOLD_SIZE as usize);
    let mut threshold_arr: [u8; SR25519_VRF_THRESHOLD_SIZE as usize] = Default::default();
    threshold_arr.copy_from_slice(&threshold[0..SR25519_VRF_THRESHOLD_SIZE as usize]);
    let threshold_int = u128::from_le_bytes(threshold_arr);

    let check = u128::from_le_bytes(raw_output) < threshold_int;

    let decomp_proof = match
        proof.shorten_vrf(&public_key, ctx.clone(), &in_out.to_preout()) {
        Ok(val) => val,
        Err(e) => return VrfResult::create_err(&e)
    };
    if in_out.to_preout() == given_out &&
        decomp_proof == given_proof {
        VrfResult::create_val(check)
    } else {
        VrfResult::create_err(&SignatureError::EquationFalse)
    }
}

#[cfg(test)]
pub mod tests {
    extern crate rand;
    extern crate schnorrkel;

    use super::*;

    use hex_literal::hex;
    use schnorrkel::{KEYPAIR_LENGTH, SECRET_KEY_LENGTH, SIGNATURE_LENGTH};

    fn generate_random_seed() -> Vec<u8> {
        (0..32).map(|_| rand::random::<u8>()).collect()
    }

    #[test]
    fn invalid_key_error_preserves_legacy_c_failure_code() {
        assert_eq!(convert_error(&SignatureError::InvalidKey), Sr25519SignatureResult::EquationFalse);
    }

    #[test]
    fn can_create_keypair() {
        let seed = generate_random_seed();
        let mut keypair = [0u8; SR25519_KEYPAIR_SIZE as usize];
        unsafe { sr25519_keypair_from_seed(keypair.as_mut_ptr(), seed.as_ptr()) };

        assert_eq!(keypair.len(), KEYPAIR_LENGTH);
    }

    #[test]
    fn creates_pair_from_known() {
        let seed = hex!("fac7959dbfe72f052e5a0c3c8d6530f202b02fd8f9f5ca3580ec8deb7797479e");
        let expected = hex!("46ebddef8cd9bb167dc30878d7113b7e168e6f0646beffd77d69d39bad76b47a");
        let mut keypair = [0u8; SR25519_KEYPAIR_SIZE as usize];
        unsafe { sr25519_keypair_from_seed(keypair.as_mut_ptr(), seed.as_ptr()) };
        let public = &keypair[SECRET_KEY_LENGTH..KEYPAIR_LENGTH];

        assert_eq!(public, expected);
    }

    #[test]
    fn can_sign_message() {
        let seed = generate_random_seed();
        let mut keypair = [0u8; SR25519_KEYPAIR_SIZE as usize];
        unsafe { sr25519_keypair_from_seed(keypair.as_mut_ptr(), seed.as_ptr()) };
        let private = &keypair[0..SECRET_KEY_LENGTH];
        let public = &keypair[SECRET_KEY_LENGTH..KEYPAIR_LENGTH];
        let message = b"this is a message";

        let mut signature = [0u8; SR25519_SIGNATURE_SIZE as usize];
        unsafe {
            sr25519_sign(
                signature.as_mut_ptr(),
                public.as_ptr(),
                private.as_ptr(),
                message.as_ptr(),
                message.len() as c_ulong,
            )
        };

        assert_eq!(signature.len(), SIGNATURE_LENGTH);
    }

    #[test]
    fn can_verify_message() {
        let seed = generate_random_seed();
        let mut keypair = [0u8; SR25519_KEYPAIR_SIZE as usize];
        unsafe { sr25519_keypair_from_seed(keypair.as_mut_ptr(), seed.as_ptr()) };
        let private = &keypair[0..SECRET_KEY_LENGTH];
        let public = &keypair[SECRET_KEY_LENGTH..KEYPAIR_LENGTH];
        let message = b"this is a message";
        let mut signature = [0u8; SR25519_SIGNATURE_SIZE as usize];
        unsafe {
            sr25519_sign(
                signature.as_mut_ptr(),
                public.as_ptr(),
                private.as_ptr(),
                message.as_ptr(),
                message.len() as c_ulong,
            )
        };
        let is_valid = unsafe {
            sr25519_verify(
                signature.as_ptr(),
                message.as_ptr(),
                message.len() as c_ulong,
                public.as_ptr(),
            )
        };

        assert!(is_valid);
    }

    #[test]
    fn checked_sign_rejects_malformed_keys_without_aborting() {
        let seed = [42u8; SR25519_SEED_SIZE as usize];
        let mut keypair = [0u8; SR25519_KEYPAIR_SIZE as usize];
        unsafe { sr25519_keypair_from_seed(keypair.as_mut_ptr(), seed.as_ptr()) };
        let (secret, public) = keypair.split_at(SR25519_SECRET_SIZE as usize);
        let message = b"checked signing";
        let mut signature = [0x55u8; SR25519_SIGNATURE_SIZE as usize];
        let malformed_secret = [0xffu8; SR25519_SECRET_SIZE as usize];
        let malformed_public = [0xffu8; SR25519_PUBLIC_SIZE as usize];

        let sign = |secret: &[u8], public: &[u8], signature: &mut [u8]| unsafe {
            sr25519_sign_checked(
                signature.as_mut_ptr(), signature.len(),
                public.as_ptr(), public.len(),
                secret.as_ptr(), secret.len(),
                message.as_ptr(), message.len(),
            )
        };
        assert_eq!(sign(&malformed_secret, public, &mut signature),
                   Sr25519SignResult::Sr25519SignInvalidSecret);
        assert_eq!(signature, [0u8; SR25519_SIGNATURE_SIZE as usize]);
        signature.fill(0x55);
        assert_eq!(sign(secret, &malformed_public, &mut signature),
                   Sr25519SignResult::Sr25519SignInvalidPublic);
        assert_eq!(signature, [0u8; SR25519_SIGNATURE_SIZE as usize]);

        assert_eq!(sign(secret, public, &mut signature),
                   Sr25519SignResult::Sr25519SignOk);
        assert!(unsafe { sr25519_verify(signature.as_ptr(), message.as_ptr(),
                                       message.len() as c_ulong, public.as_ptr()) });
    }

    #[test]
    fn soft_derives_pair() {
        let cc = hex!("0c666f6f00000000000000000000000000000000000000000000000000000000"); // foo
        let seed = hex!("fac7959dbfe72f052e5a0c3c8d6530f202b02fd8f9f5ca3580ec8deb7797479e");
        let expected = hex!("40b9675df90efa6069ff623b0fdfcf706cd47ca7452a5056c7ad58194d23440a");
        let mut keypair = [0u8; SR25519_KEYPAIR_SIZE as usize];
        let mut derived = [0u8; SR25519_KEYPAIR_SIZE as usize];
        unsafe { sr25519_keypair_from_seed(keypair.as_mut_ptr(), seed.as_ptr()) };
        unsafe { sr25519_derive_keypair_soft(derived.as_mut_ptr(), keypair.as_ptr(), cc.as_ptr()) };
        let public = &derived[SECRET_KEY_LENGTH..KEYPAIR_LENGTH];

        assert_eq!(public, expected);
    }

    #[test]
    fn soft_derives_public() {
        let cc = hex!("0c666f6f00000000000000000000000000000000000000000000000000000000"); // foo
        let public = hex!("46ebddef8cd9bb167dc30878d7113b7e168e6f0646beffd77d69d39bad76b47a");
        let expected = hex!("40b9675df90efa6069ff623b0fdfcf706cd47ca7452a5056c7ad58194d23440a");
        let mut derived = [0u8; SR25519_PUBLIC_SIZE as usize];
        unsafe { sr25519_derive_public_soft(derived.as_mut_ptr(), public.as_ptr(), cc.as_ptr()) };

        assert_eq!(derived, expected);
    }

    #[test]
    fn hard_derives_pair() {
        let cc = hex!("14416c6963650000000000000000000000000000000000000000000000000000"); // Alice
        let seed = hex!("fac7959dbfe72f052e5a0c3c8d6530f202b02fd8f9f5ca3580ec8deb7797479e");
        let expected = hex!("d43593c715fdd31c61141abd04a99fd6822c8558854ccde39a5684e7a56da27d");
        let mut keypair = [0u8; SR25519_KEYPAIR_SIZE as usize];
        unsafe { sr25519_keypair_from_seed(keypair.as_mut_ptr(), seed.as_ptr()) };
        let mut derived = [0u8; SR25519_KEYPAIR_SIZE as usize];
        unsafe { sr25519_derive_keypair_hard(derived.as_mut_ptr(), keypair.as_ptr(), cc.as_ptr()) };
        let public = &derived[SECRET_KEY_LENGTH..KEYPAIR_LENGTH];

        assert_eq!(public, expected);
    }

    #[test]
    fn vrf_verify() {
        let seed = generate_random_seed();
        let mut keypair_bytes = [0u8; SR25519_KEYPAIR_SIZE as usize];
        unsafe { sr25519_keypair_from_seed(keypair_bytes.as_mut_ptr(), seed.as_ptr()) };
        let private = &keypair_bytes[0..SECRET_KEY_LENGTH];
        let public = &keypair_bytes[SECRET_KEY_LENGTH..KEYPAIR_LENGTH];
        let message = b"Hello, world!";

        let keypair = Keypair::from_bytes(&keypair_bytes).expect("Keypair creation error");
        let ctx = signing_context(SIGNING_CTX).bytes(message);
        let (io, proof, _) = keypair.vrf_sign(ctx.clone());
        let (io_, proof_) = keypair.public.vrf_verify(ctx.clone(), &io.to_preout(), &proof).expect("Verification error");
        assert_eq!(io_, io);
        let decomp_proof = proof_.shorten_vrf(
            &keypair.public, ctx.clone(), &io.to_preout()).expect("Shorten VRF");
        assert_eq!(proof, decomp_proof);
        unsafe {
            let threshold_bytes = [0u8; SR25519_VRF_THRESHOLD_SIZE as usize];
            let res = sr25519_vrf_verify(public.as_ptr(),
                                         message.as_ptr(), message.len() as c_ulong,
                                         io.as_output_bytes().as_ptr(),
                                         proof.to_bytes().as_ptr(), threshold_bytes.as_ptr());
            assert_eq!(res.result, Sr25519SignatureResult::Ok);
        }
    }
}
