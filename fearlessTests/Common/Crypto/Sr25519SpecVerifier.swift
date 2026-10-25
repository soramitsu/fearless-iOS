import Foundation

/// sr25519 (schnorrkel 0.9) verification written from the specifications, for tests only.
///
/// It shares no code with the Rust `schnorrkel` crate that `sr25519lib.xcframework` is built
/// from: Keccak-f[1600] (FIPS 202), STROBE-128 as profiled by Merlin, Merlin transcripts,
/// ristretto255 (RFC 9496) and the schnorrkel signing transcript. It is a port of
/// `scripts/deps/sr25519-provenance/sr25519_reference.py`. Slow and not constant time: it only
/// ever handles published test vectors, so the app's own signatures can be checked by a
/// verifier that is not the library that made them.
enum Sr25519SpecVerifier {
    static let substrateContext = Data("substrate".utf8)

    /// `PublicKey::verify_simple(context, message, signature)`.
    static func verify(
        signature: Data,
        message: Data,
        publicKey: Data,
        context: Data = substrateContext
    ) -> Bool {
        let signature = [UInt8](signature)
        guard signature.count == 64, publicKey.count == 32 else { return false }
        // schnorrkel marks its signatures in the top bit of s.
        guard signature[63] & 0x80 != 0 else { return false }

        var sBytes = Array(signature[32 ..< 64])
        sBytes[31] &= 0x7F
        let rBytes = Data(signature[0 ..< 32])
        guard
            let s = Scalar.canonical(sBytes),
            let a = Ristretto.decode(publicKey),
            Ristretto.decode(rBytes) != nil
        else { return false }

        var transcript = MerlinTranscript(label: "SigningContext")
        transcript.appendMessage(label: "", message: context)
        transcript.appendMessage(label: "sign-bytes", message: message)
        transcript.appendMessage(label: "proto-name", message: Data("Schnorr-sig".utf8))
        transcript.appendMessage(label: "sign:pk", message: publicKey)
        transcript.appendMessage(label: "sign:R", message: rBytes)
        let k = Scalar.reduceWide(transcript.challengeBytes(label: "sign:c", count: 64))

        let r = EdwardsPoint.base.multiplied(by: s) + a.negated.multiplied(by: k)
        return Ristretto.encode(r) == rBytes
    }

    /// The public key a stored 64-byte secret (canonical scalar || nonce) belongs to,
    /// or nil when the scalar is not canonical.
    static func publicKey(fromSecret secret: Data) -> Data? {
        guard secret.count == 64, let scalar = Scalar.canonical(Array(secret.prefix(32))) else {
            return nil
        }
        return Ristretto.encode(EdwardsPoint.base.multiplied(by: scalar))
    }

    /// Exposed so tests can check the constants against their defining equations.
    static var curveConstantsHold: Bool {
        let minusOne = FieldElement.zero - .one
        let d = FieldElement.d
        return d * FieldElement(small: 121_666) == FieldElement.zero - FieldElement(small: 121_665)
            && FieldElement.sqrtM1 * FieldElement.sqrtM1 == minusOne
            && FieldElement.invsqrtAMinusD.squared() * (minusOne - d) == .one
            && EdwardsPoint.base.isOnCurve
    }

    static var encodedBasePoint: Data {
        Ristretto.encode(.base)
    }
}

// MARK: - Multi-precision helpers (little-endian 64-bit limbs)

private enum Limbs {
    static func compare(_ lhs: [UInt64], _ rhs: [UInt64]) -> Int {
        for index in stride(from: lhs.count - 1, through: 0, by: -1) where lhs[index] != rhs[index] {
            return lhs[index] < rhs[index] ? -1 : 1
        }
        return 0
    }

    static func add(_ lhs: [UInt64], _ rhs: [UInt64]) -> (sum: [UInt64], carry: Bool) {
        var result = lhs
        var carry: UInt64 = 0
        for index in 0 ..< lhs.count {
            let (partial, overflow1) = lhs[index].addingReportingOverflow(rhs[index])
            let (total, overflow2) = partial.addingReportingOverflow(carry)
            result[index] = total
            carry = (overflow1 ? 1 : 0) + (overflow2 ? 1 : 0)
        }
        return (result, carry != 0)
    }

    static func subtract(_ lhs: [UInt64], _ rhs: [UInt64]) -> (difference: [UInt64], borrow: Bool) {
        var result = lhs
        var borrow: UInt64 = 0
        for index in 0 ..< lhs.count {
            let (partial, overflow1) = lhs[index].subtractingReportingOverflow(rhs[index])
            let (total, overflow2) = partial.subtractingReportingOverflow(borrow)
            result[index] = total
            borrow = (overflow1 ? 1 : 0) + (overflow2 ? 1 : 0)
        }
        return (result, borrow != 0)
    }

    static func fromLittleEndian(_ bytes: [UInt8]) -> [UInt64] {
        stride(from: 0, to: bytes.count, by: 8).map { offset in
            (0 ..< 8).reduce(UInt64(0)) { value, shift in
                value | UInt64(bytes[offset + shift]) << (8 * UInt64(shift))
            }
        }
    }

    static func toLittleEndian(_ limbs: [UInt64]) -> [UInt8] {
        limbs.flatMap { limb in (0 ..< 8).map { UInt8(truncatingIfNeeded: limb >> (8 * UInt64($0))) } }
    }

    static func bit(_ limbs: [UInt64], _ index: Int) -> Bool {
        (limbs[index / 64] >> UInt64(index % 64)) & 1 == 1
    }
}

// MARK: - GF(2^255 - 19)

private typealias Limbs4 = (UInt64, UInt64, UInt64, UInt64)

private struct FieldElement: Equatable {
    /// Little-endian limbs, always fully reduced: 0 <= value < p. A tuple rather than an
    /// array keeps the Debug test build free of allocations in the inner loops.
    let w: Limbs4

    static let p: Limbs4 = (0xFFFF_FFFF_FFFF_FFED, 0xFFFF_FFFF_FFFF_FFFF, 0xFFFF_FFFF_FFFF_FFFF, 0x7FFF_FFFF_FFFF_FFFF)
    static let zero = FieldElement(w: (0, 0, 0, 0))
    static let one = FieldElement(w: (1, 0, 0, 0))
    static let d = FieldElement(w: (
        0x75EB_4DCA_1359_78A3, 0x0070_0A4D_4141_D8AB, 0x8CC7_4079_7779_E898, 0x5203_6CEE_2B6F_FE73
    ))
    static let sqrtM1 = FieldElement(w: (
        0xC4EE_1B27_4A0E_A0B0, 0x2F43_1806_AD2F_E478, 0x2B4D_0099_3DFB_D7A7, 0x2B83_2480_4FC1_DF0B
    ))
    static let invsqrtAMinusD = FieldElement(w: (
        0x99C8_FDAA_805D_40EA, 0x9D2F_1617_5A41_72BE, 0x16C2_7B91_FE01_D840, 0x786C_8905_CFAF_FCA2
    ))
    /// (p - 5) / 8
    private static let sqrtExponent: [UInt64] = [
        0xFFFF_FFFF_FFFF_FFFD, 0xFFFF_FFFF_FFFF_FFFF, 0xFFFF_FFFF_FFFF_FFFF, 0x0FFF_FFFF_FFFF_FFFF
    ]

    init(w: Limbs4) {
        self.w = w
    }

    init(small value: UInt64) {
        w = (value, 0, 0, 0)
    }

    /// Canonical little-endian encoding only; nil when the value is not below p.
    init?(canonical bytes: [UInt8]) {
        guard bytes.count == 32 else { return nil }
        let limbs = Limbs.fromLittleEndian(bytes)
        let value = (limbs[0], limbs[1], limbs[2], limbs[3])
        guard !Self.isAtLeastP(value) else { return nil }
        w = value
    }

    static func == (lhs: FieldElement, rhs: FieldElement) -> Bool {
        lhs.w == rhs.w
    }

    var bytes: [UInt8] {
        Limbs.toLittleEndian([w.0, w.1, w.2, w.3])
    }

    var isNegative: Bool {
        w.0 & 1 == 1
    }

    var isZero: Bool {
        self == .zero
    }

    var absolute: FieldElement {
        isNegative ? .zero - self : self
    }

    static func + (lhs: FieldElement, rhs: FieldElement) -> FieldElement {
        // Both operands are below p, so the sum is below 2p < 2^256 and cannot carry out.
        let (r0, c0) = addWithCarry(lhs.w.0, rhs.w.0, 0)
        let (r1, c1) = addWithCarry(lhs.w.1, rhs.w.1, c0)
        let (r2, c2) = addWithCarry(lhs.w.2, rhs.w.2, c1)
        let (r3, _) = addWithCarry(lhs.w.3, rhs.w.3, c2)
        return FieldElement(w: subtractingPIfNeeded((r0, r1, r2, r3)))
    }

    static func - (lhs: FieldElement, rhs: FieldElement) -> FieldElement {
        let (r0, b0) = subtractWithBorrow(lhs.w.0, rhs.w.0, 0)
        let (r1, b1) = subtractWithBorrow(lhs.w.1, rhs.w.1, b0)
        let (r2, b2) = subtractWithBorrow(lhs.w.2, rhs.w.2, b1)
        let (r3, b3) = subtractWithBorrow(lhs.w.3, rhs.w.3, b2)
        guard b3 != 0 else { return FieldElement(w: (r0, r1, r2, r3)) }
        // The limbs hold lhs - rhs + 2^256; adding p and dropping the carry leaves
        // lhs - rhs + p, which is in [0, p).
        let (s0, c0) = addWithCarry(r0, p.0, 0)
        let (s1, c1) = addWithCarry(r1, p.1, c0)
        let (s2, c2) = addWithCarry(r2, p.2, c1)
        let (s3, _) = addWithCarry(r3, p.3, c2)
        return FieldElement(w: (s0, s1, s2, s3))
    }

    static func * (lhs: FieldElement, rhs: FieldElement) -> FieldElement {
        let a = [lhs.w.0, lhs.w.1, lhs.w.2, lhs.w.3]
        let b = [rhs.w.0, rhs.w.1, rhs.w.2, rhs.w.3]
        var t = (UInt64(0), UInt64(0), UInt64(0), UInt64(0), UInt64(0), UInt64(0), UInt64(0), UInt64(0))
        withUnsafeMutableBytes(of: &t) { raw in
            let product = raw.bindMemory(to: UInt64.self)
            for i in 0 ..< 4 {
                var carry: UInt64 = 0
                for j in 0 ..< 4 {
                    let (high, low) = a[i].multipliedFullWidth(by: b[j])
                    let (sum, overflow) = addWithCarry(product[i + j], low, carry)
                    product[i + j] = sum
                    // high <= 2^64 - 2, and when it is that large low is 1 and at most one
                    // addition overflows, so this cannot wrap.
                    carry = high + overflow
                }
                product[i + 4] = carry
            }
        }
        return reduce(t)
    }

    func squared() -> FieldElement {
        self * self
    }

    func power(_ exponent: [UInt64]) -> FieldElement {
        var result = FieldElement.one
        for index in stride(from: 255, through: 0, by: -1) {
            result = result.squared()
            if Limbs.bit(exponent, index) {
                result = result * self
            }
        }
        return result
    }

    /// RFC 9496 SQRT_RATIO_M1: (u/v is square, nonnegative root of u/v or of i*u/v).
    static func sqrtRatioM1(_ u: FieldElement, _ v: FieldElement) -> (wasSquare: Bool, root: FieldElement) {
        let v3 = v.squared() * v
        let v7 = v3.squared() * v
        var root = (u * v3) * (u * v7).power(sqrtExponent)
        let check = v * root.squared()
        let correctSign = check == u
        let flippedSign = check == zero - u
        let flippedSignI = check == (zero - u) * sqrtM1
        if flippedSign || flippedSignI {
            root = root * sqrtM1
        }
        return (correctSign || flippedSign, root.absolute)
    }

    private static func addWithCarry(_ x: UInt64, _ y: UInt64, _ carry: UInt64) -> (UInt64, UInt64) {
        let (partial, overflow1) = x.addingReportingOverflow(y)
        let (total, overflow2) = partial.addingReportingOverflow(carry)
        return (total, (overflow1 ? 1 : 0) + (overflow2 ? 1 : 0))
    }

    private static func subtractWithBorrow(_ x: UInt64, _ y: UInt64, _ borrow: UInt64) -> (UInt64, UInt64) {
        let (partial, overflow1) = x.subtractingReportingOverflow(y)
        let (total, overflow2) = partial.subtractingReportingOverflow(borrow)
        return (total, (overflow1 ? 1 : 0) + (overflow2 ? 1 : 0))
    }

    private static func isAtLeastP(_ value: Limbs4) -> Bool {
        if value.3 != p.3 {
            return value.3 > p.3
        }
        if value.2 != p.2 {
            return value.2 > p.2
        }
        if value.1 != p.1 {
            return value.1 > p.1
        }
        return value.0 >= p.0
    }

    private static func subtractingPIfNeeded(_ value: Limbs4) -> Limbs4 {
        var value = value
        while isAtLeastP(value) {
            let (r0, b0) = subtractWithBorrow(value.0, p.0, 0)
            let (r1, b1) = subtractWithBorrow(value.1, p.1, b0)
            let (r2, b2) = subtractWithBorrow(value.2, p.2, b1)
            let (r3, _) = subtractWithBorrow(value.3, p.3, b2)
            value = (r0, r1, r2, r3)
        }
        return value
    }

    /// Reduces a 512-bit product using 2^256 = 38 (mod p).
    private static func reduce(
        _ t: (UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64)
    ) -> FieldElement {
        let (h0, l0) = t.4.multipliedFullWidth(by: 38)
        let (h1, l1) = t.5.multipliedFullWidth(by: 38)
        let (h2, l2) = t.6.multipliedFullWidth(by: 38)
        let (h3, l3) = t.7.multipliedFullWidth(by: 38)
        var (r0, c) = addWithCarry(t.0, l0, 0)
        var carry = h0 + c
        var r1: UInt64, r2: UInt64, r3: UInt64
        (r1, c) = addWithCarry(t.1, l1, carry)
        carry = h1 + c
        (r2, c) = addWithCarry(t.2, l2, carry)
        carry = h2 + c
        (r3, c) = addWithCarry(t.3, l3, carry)
        carry = h3 + c
        // carry < 40: fold carry * 2^256, and once more if that wraps past 2^256.
        var extra = carry * 38
        while extra != 0 {
            (r0, c) = addWithCarry(r0, extra, 0)
            (r1, c) = addWithCarry(r1, 0, c)
            (r2, c) = addWithCarry(r2, 0, c)
            (r3, c) = addWithCarry(r3, 0, c)
            extra = c * 38
        }
        return FieldElement(w: subtractingPIfNeeded((r0, r1, r2, r3)))
    }
}

// MARK: - Scalars modulo the group order

private enum Scalar {
    static let order: [UInt64] = [0x5812_631A_5CF5_D3ED, 0x14DE_F9DE_A2F7_9CD6, 0, 0x1000_0000_0000_0000]

    /// 32 little-endian bytes that must already be below the group order.
    static func canonical(_ bytes: [UInt8]) -> [UInt64]? {
        guard bytes.count == 32 else { return nil }
        let limbs = Limbs.fromLittleEndian(bytes)
        return Limbs.compare(limbs, order) < 0 ? limbs : nil
    }

    /// `Scalar::from_bytes_mod_order_wide`: a 64-byte little-endian integer reduced mod l.
    static func reduceWide(_ bytes: Data) -> [UInt64] {
        let wide = Limbs.fromLittleEndian([UInt8](bytes))
        var result: [UInt64] = [0, 0, 0, 0]
        for index in stride(from: wide.count * 64 - 1, through: 0, by: -1) {
            // result < l < 2^253, so doubling fits in 256 bits.
            result = Limbs.add(result, result).sum
            if Limbs.bit(wide, index) {
                result[0] |= 1
            }
            if Limbs.compare(result, order) >= 0 {
                result = Limbs.subtract(result, order).difference
            }
        }
        return result
    }
}

// MARK: - Edwards25519 points in extended coordinates

private struct EdwardsPoint {
    let x: FieldElement
    let y: FieldElement
    let z: FieldElement
    let t: FieldElement

    static let identity = EdwardsPoint(x: .zero, y: .one, z: .one, t: .zero)
    static let base: EdwardsPoint = {
        let x = FieldElement(w: (
            0xC956_2D60_8F25_D51A, 0x692C_C760_9525_A7B2, 0xC0A4_E231_FDD6_DC5C, 0x2169_36D3_CD6E_53FE
        ))
        let y = FieldElement(w: (
            0x6666_6666_6666_6658, 0x6666_6666_6666_6666, 0x6666_6666_6666_6666, 0x6666_6666_6666_6666
        ))
        return EdwardsPoint(x: x, y: y, z: .one, t: x * y)
    }()

    var negated: EdwardsPoint {
        EdwardsPoint(x: .zero - x, y: y, z: z, t: .zero - t)
    }

    /// -x^2 + y^2 = 1 + d x^2 y^2 for an affine point (z = 1).
    var isOnCurve: Bool {
        let xx = x.squared()
        let yy = y.squared()
        return z == .one && yy - xx == .one + FieldElement.d * xx * yy
    }

    /// Unified addition for a = -1 (add-2008-hwcd-3); also valid for doubling.
    static func + (lhs: EdwardsPoint, rhs: EdwardsPoint) -> EdwardsPoint {
        let a = (lhs.y - lhs.x) * (rhs.y - rhs.x)
        let b = (lhs.y + lhs.x) * (rhs.y + rhs.x)
        let twoD = FieldElement.d + FieldElement.d
        let c = lhs.t * twoD * rhs.t
        let zz = lhs.z * rhs.z
        let d = zz + zz
        let e = b - a
        let f = d - c
        let g = d + c
        let h = b + a
        return EdwardsPoint(x: e * f, y: g * h, z: f * g, t: e * h)
    }

    func multiplied(by scalar: [UInt64]) -> EdwardsPoint {
        var result = EdwardsPoint.identity
        for index in stride(from: 255, through: 0, by: -1) {
            result = result + result
            if Limbs.bit(scalar, index) {
                result = result + self
            }
        }
        return result
    }
}

// MARK: - ristretto255 (RFC 9496)

private enum Ristretto {
    static func decode(_ data: Data) -> EdwardsPoint? {
        guard let s = FieldElement(canonical: [UInt8](data)), !s.isNegative else { return nil }
        let ss = s.squared()
        let u1 = FieldElement.one - ss
        let u2 = FieldElement.one + ss
        let u2Squared = u2.squared()
        let v = FieldElement.zero - FieldElement.d * u1.squared() - u2Squared
        let (wasSquare, invsqrt) = FieldElement.sqrtRatioM1(.one, v * u2Squared)
        let denX = invsqrt * u2
        let denY = invsqrt * denX * v
        let x = (s + s) * denX
        let absoluteX = x.absolute
        let y = u1 * denY
        let t = absoluteX * y
        guard wasSquare, !t.isNegative, !y.isZero else { return nil }
        return EdwardsPoint(x: absoluteX, y: y, z: .one, t: t)
    }

    static func encode(_ point: EdwardsPoint) -> Data {
        let u1 = (point.z + point.y) * (point.z - point.y)
        let u2 = point.x * point.y
        let (_, invsqrt) = FieldElement.sqrtRatioM1(.one, u1 * u2.squared())
        let den1 = invsqrt * u1
        let den2 = invsqrt * u2
        let zInv = den1 * den2 * point.t
        let rotate = (point.t * zInv).isNegative
        let x = rotate ? point.y * FieldElement.sqrtM1 : point.x
        var y = rotate ? point.x * FieldElement.sqrtM1 : point.y
        let denInv = rotate ? den1 * FieldElement.invsqrtAMinusD : den2
        if (x * zInv).isNegative {
            y = FieldElement.zero - y
        }
        return Data((denInv * (point.z - y)).absolute.bytes)
    }
}

// MARK: - Keccak-f[1600], STROBE-128 and Merlin

private enum Keccak {
    private static let roundConstants: [UInt64] = [
        0x0000_0000_0000_0001, 0x0000_0000_0000_8082, 0x8000_0000_0000_808A, 0x8000_0000_8000_8000,
        0x0000_0000_0000_808B, 0x0000_0000_8000_0001, 0x8000_0000_8000_8081, 0x8000_0000_0000_8009,
        0x0000_0000_0000_008A, 0x0000_0000_0000_0088, 0x0000_0000_8000_8009, 0x0000_0000_8000_000A,
        0x0000_0000_8000_808B, 0x8000_0000_0000_008B, 0x8000_0000_0000_8089, 0x8000_0000_0000_8003,
        0x8000_0000_0000_8002, 0x8000_0000_0000_0080, 0x0000_0000_0000_800A, 0x8000_0000_8000_000A,
        0x8000_0000_8000_8081, 0x8000_0000_0000_8080, 0x0000_0000_8000_0001, 0x8000_0000_8000_8008
    ]

    /// Rotation offsets indexed [x][y].
    private static let rotations: [[UInt64]] = [
        [0, 36, 3, 41, 18], [1, 44, 10, 45, 2], [62, 6, 43, 15, 61], [28, 55, 25, 21, 56], [27, 20, 39, 8, 14]
    ]

    private static func rotateLeft(_ value: UInt64, _ shift: UInt64) -> UInt64 {
        shift == 0 ? value : (value << shift) | (value >> (64 - shift))
    }

    static func permute(_ state: inout [UInt8]) {
        var lanes = Limbs.fromLittleEndian(state) // lane (x, y) at x + 5y
        for constant in roundConstants {
            var c = [UInt64](repeating: 0, count: 5)
            for x in 0 ..< 5 {
                for y in 0 ..< 5 {
                    c[x] ^= lanes[x + 5 * y]
                }
            }
            for x in 0 ..< 5 {
                let d = c[(x + 4) % 5] ^ rotateLeft(c[(x + 1) % 5], 1)
                for y in 0 ..< 5 {
                    lanes[x + 5 * y] ^= d
                }
            }
            var b = [UInt64](repeating: 0, count: 25)
            for x in 0 ..< 5 {
                for y in 0 ..< 5 {
                    b[y + 5 * ((2 * x + 3 * y) % 5)] = rotateLeft(lanes[x + 5 * y], rotations[x][y])
                }
            }
            for x in 0 ..< 5 {
                for y in 0 ..< 5 {
                    lanes[x + 5 * y] = b[x + 5 * y] ^ (~b[(x + 1) % 5 + 5 * y] & b[(x + 2) % 5 + 5 * y])
                }
            }
            lanes[0] ^= constant
        }
        state = Limbs.toLittleEndian(lanes)
    }
}

/// The subset of STROBE-128 that Merlin uses (meta-AD, AD and PRF).
private struct Strobe128 {
    private static let rate = 166
    private static let flagI: UInt8 = 1
    private static let flagA: UInt8 = 2
    private static let flagC: UInt8 = 4
    private static let flagM: UInt8 = 16
    private static let flagK: UInt8 = 32

    private var state: [UInt8]
    private var position = 0
    private var positionBegin = 0
    private var currentFlags: UInt8 = 0

    init(protocolLabel: Data) {
        var initial = [UInt8](repeating: 0, count: 200)
        initial.replaceSubrange(0 ..< 6, with: [1, UInt8(Self.rate + 2), 1, 0, 1, 96])
        initial.replaceSubrange(6 ..< 18, with: Array("STROBEv1.0.2".utf8))
        Keccak.permute(&initial)
        state = initial
        metaAD(protocolLabel, more: false)
    }

    mutating func metaAD(_ data: Data, more: Bool) {
        beginOperation(flags: Self.flagM | Self.flagA, more: more)
        absorb([UInt8](data))
    }

    mutating func ad(_ data: Data, more: Bool) {
        beginOperation(flags: Self.flagA, more: more)
        absorb([UInt8](data))
    }

    mutating func prf(count: Int, more: Bool) -> Data {
        beginOperation(flags: Self.flagI | Self.flagA | Self.flagC, more: more)
        return squeeze(count: count)
    }

    private mutating func runF() {
        state[position] ^= UInt8(positionBegin)
        state[position + 1] ^= 0x04
        state[Self.rate + 1] ^= 0x80
        Keccak.permute(&state)
        position = 0
        positionBegin = 0
    }

    private mutating func absorb(_ bytes: [UInt8]) {
        for byte in bytes {
            state[position] ^= byte
            position += 1
            if position == Self.rate {
                runF()
            }
        }
    }

    private mutating func squeeze(count: Int) -> Data {
        var output = [UInt8]()
        for _ in 0 ..< count {
            output.append(state[position])
            state[position] = 0
            position += 1
            if position == Self.rate {
                runF()
            }
        }
        return Data(output)
    }

    private mutating func beginOperation(flags: UInt8, more: Bool) {
        if more {
            precondition(currentFlags == flags, "STROBE continuation with different flags")
            return
        }
        let oldBegin = positionBegin
        positionBegin = position + 1
        currentFlags = flags
        absorb([UInt8(oldBegin), flags])
        if flags & (Self.flagC | Self.flagK) != 0, position != 0 {
            runF()
        }
    }
}

private struct MerlinTranscript {
    private var strobe = Strobe128(protocolLabel: Data("Merlin v1.0".utf8))

    init(label: String) {
        appendMessage(label: "dom-sep", message: Data(label.utf8))
    }

    mutating func appendMessage(label: String, message: Data) {
        strobe.metaAD(Data(label.utf8), more: false)
        strobe.metaAD(Self.littleEndianLength(message.count), more: true)
        strobe.ad(message, more: false)
    }

    mutating func challengeBytes(label: String, count: Int) -> Data {
        strobe.metaAD(Data(label.utf8), more: false)
        strobe.metaAD(Self.littleEndianLength(count), more: true)
        return strobe.prf(count: count, more: false)
    }

    private static func littleEndianLength(_ length: Int) -> Data {
        withUnsafeBytes(of: UInt32(length).littleEndian) { Data($0) }
    }
}
