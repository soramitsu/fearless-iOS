"""sr25519 (schnorrkel) written from the specifications, with no native code.

Independent of the Rust `schnorrkel` crate that `sr25519lib.xcframework` is built
from: Keccak-f[1600] (FIPS 202), STROBE-128 as profiled by Merlin, Merlin
transcripts, ristretto255 (RFC 9496) and the schnorrkel 0.9 transcript labels. Slow
and not constant time: it handles published test vectors only.
"""
import hashlib

# --- Keccak-f[1600] -----------------------------------------------------------------

_ROUND_CONSTANTS = [
    0x0000000000000001, 0x0000000000008082, 0x800000000000808A, 0x8000000080008000,
    0x000000000000808B, 0x0000000080000001, 0x8000000080008081, 0x8000000000008009,
    0x000000000000008A, 0x0000000000000088, 0x0000000080008009, 0x000000008000000A,
    0x000000008000808B, 0x800000000000008B, 0x8000000000008089, 0x8000000000008003,
    0x8000000000008002, 0x8000000000000080, 0x000000000000800A, 0x800000008000000A,
    0x8000000080008081, 0x8000000000008080, 0x0000000080000001, 0x8000000080008008,
]
_ROTATIONS = [
    [0, 36, 3, 41, 18], [1, 44, 10, 45, 2], [62, 6, 43, 15, 61],
    [28, 55, 25, 21, 56], [27, 20, 39, 8, 14],
]
_MASK = (1 << 64) - 1


def _rotl(value, shift):
    return ((value << shift) | (value >> (64 - shift))) & _MASK if shift else value


def keccak_f1600(state):
    lanes = [[int.from_bytes(state[8 * (x + 5 * y):8 * (x + 5 * y) + 8], "little") for y in range(5)]
             for x in range(5)]
    for constant in _ROUND_CONSTANTS:
        c = [lanes[x][0] ^ lanes[x][1] ^ lanes[x][2] ^ lanes[x][3] ^ lanes[x][4] for x in range(5)]
        d = [c[(x - 1) % 5] ^ _rotl(c[(x + 1) % 5], 1) for x in range(5)]
        lanes = [[lanes[x][y] ^ d[x] for y in range(5)] for x in range(5)]
        b = [[0] * 5 for _ in range(5)]
        for x in range(5):
            for y in range(5):
                b[y][(2 * x + 3 * y) % 5] = _rotl(lanes[x][y], _ROTATIONS[x][y])
        lanes = [[b[x][y] ^ ((~b[(x + 1) % 5][y]) & b[(x + 2) % 5][y]) for y in range(5)] for x in range(5)]
        lanes[0][0] ^= constant
    out = bytearray(200)
    for x in range(5):
        for y in range(5):
            out[8 * (x + 5 * y):8 * (x + 5 * y) + 8] = lanes[x][y].to_bytes(8, "little")
    return out


# --- STROBE-128 (the subset Merlin uses) and Merlin ---------------------------------

_STROBE_R = 166
_FLAG_I, _FLAG_A, _FLAG_C, _FLAG_T, _FLAG_M, _FLAG_K = 1, 2, 4, 8, 16, 32


class Strobe128:
    def __init__(self, protocol_label):
        state = bytearray(200)
        state[0:6] = bytes([1, _STROBE_R + 2, 1, 0, 1, 96])
        state[6:18] = b"STROBEv1.0.2"
        self.state = keccak_f1600(state)
        self.pos = 0
        self.pos_begin = 0
        self.cur_flags = 0
        self.meta_ad(protocol_label, False)

    def clone(self):
        other = object.__new__(Strobe128)
        other.state = bytearray(self.state)
        other.pos, other.pos_begin, other.cur_flags = self.pos, self.pos_begin, self.cur_flags
        return other

    def _run_f(self):
        self.state[self.pos] ^= self.pos_begin
        self.state[self.pos + 1] ^= 0x04
        self.state[_STROBE_R + 1] ^= 0x80
        self.state = keccak_f1600(self.state)
        self.pos = 0
        self.pos_begin = 0

    def _absorb(self, data):
        for byte in data:
            self.state[self.pos] ^= byte
            self.pos += 1
            if self.pos == _STROBE_R:
                self._run_f()

    def _squeeze(self, count):
        out = bytearray()
        for _ in range(count):
            out.append(self.state[self.pos])
            self.state[self.pos] = 0
            self.pos += 1
            if self.pos == _STROBE_R:
                self._run_f()
        return bytes(out)

    def _begin_op(self, flags, more):
        if more:
            assert self.cur_flags == flags
            return
        assert flags & _FLAG_T == 0
        old_begin = self.pos_begin
        self.pos_begin = self.pos + 1
        self.cur_flags = flags
        self._absorb(bytes([old_begin, flags]))
        if flags & (_FLAG_C | _FLAG_K) and self.pos != 0:
            self._run_f()

    def meta_ad(self, data, more):
        self._begin_op(_FLAG_M | _FLAG_A, more)
        self._absorb(data)

    def ad(self, data, more):
        self._begin_op(_FLAG_A, more)
        self._absorb(data)

    def prf(self, count, more):
        self._begin_op(_FLAG_I | _FLAG_A | _FLAG_C, more)
        return self._squeeze(count)


class Transcript:
    def __init__(self, label):
        self.strobe = Strobe128(b"Merlin v1.0")
        self.append_message(b"dom-sep", label)

    def clone(self):
        other = object.__new__(Transcript)
        other.strobe = self.strobe.clone()
        return other

    def append_message(self, label, message):
        self.strobe.meta_ad(label, False)
        self.strobe.meta_ad(len(message).to_bytes(4, "little"), True)
        self.strobe.ad(message, False)

    def challenge_bytes(self, label, count):
        self.strobe.meta_ad(label, False)
        self.strobe.meta_ad(count.to_bytes(4, "little"), True)
        return self.strobe.prf(count, False)


# --- ristretto255 (RFC 9496) ---------------------------------------------------------

P = 2 ** 255 - 19
L = 2 ** 252 + 27742317777372353535851937790883648493
D = 37095705934669439343138083508754565189542113879843219016388785533085940283555
SQRT_M1 = 19681161376707505956807079304988542015446066515923890162744021073123829784752
INVSQRT_A_MINUS_D = 54469307008909316920995813868745141605393597292927456921205312896311721017578
_BASE_X = 15112221349535400772501151409588531511454012693041857206046113283949847762202
_BASE_Y = 46316835694926478169428394003475163141307993866256225615783033603165251855960
BASE = (_BASE_X, _BASE_Y, 1, _BASE_X * _BASE_Y % P)
IDENTITY = (0, 1, 1, 0)


def _is_negative(value):
    return value % P & 1 == 1


def _abs(value):
    value %= P
    return P - value if value & 1 else value


def _sqrt_ratio_m1(u, v):
    r = (u * pow(v, 3, P)) * pow(u * pow(v, 7, P), (P - 5) // 8, P) % P
    check = v * r * r % P
    correct = check == u % P
    flipped = check == (-u) % P
    flipped_i = check == (-u * SQRT_M1) % P
    if flipped or flipped_i:
        r = r * SQRT_M1 % P
    return correct or flipped, _abs(r)


def ristretto_decode(data):
    if len(data) != 32:
        return None
    s = int.from_bytes(data, "little")
    if s >= P or s & 1:
        return None
    ss = s * s % P
    u1 = (1 - ss) % P
    u2 = (1 + ss) % P
    u2_sqr = u2 * u2 % P
    v = (-(D * u1 * u1) - u2_sqr) % P
    was_square, invsqrt = _sqrt_ratio_m1(1, v * u2_sqr % P)
    den_x = invsqrt * u2 % P
    den_y = invsqrt * den_x * v % P
    x = _abs(2 * s * den_x)
    y = u1 * den_y % P
    t = x * y % P
    if not was_square or _is_negative(t) or y == 0:
        return None
    return (x, y, 1, t)


def ristretto_encode(point):
    x0, y0, z0, t0 = point
    u1 = (z0 + y0) * (z0 - y0) % P
    u2 = x0 * y0 % P
    _, invsqrt = _sqrt_ratio_m1(1, u1 * u2 * u2 % P)
    den1 = invsqrt * u1 % P
    den2 = invsqrt * u2 % P
    z_inv = den1 * den2 * t0 % P
    ix0 = x0 * SQRT_M1 % P
    iy0 = y0 * SQRT_M1 % P
    enchanted_denominator = den1 * INVSQRT_A_MINUS_D % P
    rotate = _is_negative(t0 * z_inv)
    x, y, den_inv = (iy0, ix0, enchanted_denominator) if rotate else (x0, y0, den2)
    if _is_negative(x * z_inv):
        y = (-y) % P
    return _abs(den_inv * (z0 - y)).to_bytes(32, "little")


def point_add(p, q):
    x1, y1, z1, t1 = p
    x2, y2, z2, t2 = q
    a = (y1 - x1) * (y2 - x2) % P
    b = (y1 + x1) * (y2 + x2) % P
    c = t1 * 2 * D * t2 % P
    d = z1 * 2 * z2 % P
    e, f, g, h = b - a, d - c, d + c, b + a
    return (e * f % P, g * h % P, f * g % P, e * h % P)


def point_negate(p):
    return ((-p[0]) % P, p[1], p[2], (-p[3]) % P)


def scalar_mul(scalar, point):
    result = IDENTITY
    addend = point
    while scalar:
        if scalar & 1:
            result = point_add(result, addend)
        addend = point_add(addend, addend)
        scalar >>= 1
    return result


# --- schnorrkel ---------------------------------------------------------------------

SIGNING_CONTEXT = b"substrate"


def public_from_secret(secret):
    """Public key of a stored 64-byte secret (canonical scalar || nonce)."""
    scalar = int.from_bytes(secret[:32], "little")
    if scalar >= L:
        raise ValueError("non-canonical scalar")
    return ristretto_encode(scalar_mul(scalar, BASE))


def _signing_transcript(message, context=SIGNING_CONTEXT):
    transcript = Transcript(b"SigningContext")
    transcript.append_message(b"", context)
    transcript.append_message(b"sign-bytes", message)
    return transcript


def verify(signature, message, public, context=SIGNING_CONTEXT):
    if len(signature) != 64 or len(public) != 32:
        return False
    if signature[63] & 0x80 == 0:
        return False  # not marked as a schnorrkel signature
    s = int.from_bytes(signature[32:63] + bytes([signature[63] & 0x7F]), "little")
    if s >= L:
        return False
    a = ristretto_decode(public)
    if a is None or ristretto_decode(signature[:32]) is None:
        return False
    transcript = _signing_transcript(message, context)
    transcript.append_message(b"proto-name", b"Schnorr-sig")
    transcript.append_message(b"sign:pk", public)
    transcript.append_message(b"sign:R", signature[:32])
    k = int.from_bytes(transcript.challenge_bytes(b"sign:c", 64), "little") % L
    r = point_add(scalar_mul(s, BASE), scalar_mul(k, point_negate(a)))
    return ristretto_encode(r) == signature[:32]


def secret_from_mini(mini):
    """MiniSecretKey::expand(ExpansionMode::Ed25519) -> canonical scalar || nonce."""
    digest = hashlib.sha512(mini).digest()
    key = bytearray(digest[:32])
    key[0] &= 248
    key[31] &= 63
    key[31] |= 64
    scalar = int.from_bytes(key, "little") >> 3
    return scalar.to_bytes(32, "little") + digest[32:]


def derive_hard(secret, chaincode):
    """SecretKey::hard_derive_mini_secret_key(Some(cc), b"") then Ed25519 expansion."""
    transcript = Transcript(b"SchnorrRistrettoHDKD")
    transcript.append_message(b"sign-bytes", b"")
    transcript.append_message(b"chain-code", chaincode)
    transcript.append_message(b"secret-key", secret[:32])
    return secret_from_mini(transcript.challenge_bytes(b"HDKD-hard", 32))


def derive_soft_scalar(secret, chaincode):
    """Keypair::derived_key_simple(cc, b""): the scalar is deterministic, the nonce is not."""
    public = public_from_secret(secret)
    transcript = Transcript(b"SchnorrRistrettoHDKD")
    transcript.append_message(b"sign-bytes", b"")
    transcript.append_message(b"chain-code", chaincode)
    transcript.append_message(b"public-key", public)
    tweak = int.from_bytes(transcript.challenge_bytes(b"HDKD-scalar", 64), "little") % L
    scalar = (int.from_bytes(secret[:32], "little") + tweak) % L
    return scalar.to_bytes(32, "little")


def to_ed25519_bytes(secret):
    """SecretKey::to_ed25519_bytes: the scalar multiplied by the cofactor, then the nonce."""
    scalar = int.from_bytes(secret[:32], "little") * 8
    return scalar.to_bytes(32, "little") + secret[32:]


def from_ed25519_bytes(secret):
    """SecretKey::from_ed25519_bytes: the scalar divided by the cofactor (bit shift), then the nonce."""
    scalar = int.from_bytes(secret[:32], "little") >> 3
    return scalar.to_bytes(32, "little") + secret[32:]


def substrate_mini_secret(entropy, password=""):
    """substrate-bip39: PBKDF2-HMAC-SHA512 over the entropy, first 32 bytes."""
    salt = ("mnemonic" + password).encode()
    return hashlib.pbkdf2_hmac("sha512", entropy, salt, 2048, 64)[:32]
