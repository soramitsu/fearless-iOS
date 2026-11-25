import BigInt
import Foundation

/// BLAKE3 for inputs of one chunk (at most 1024 bytes), enough for Iroha asset-definition checksums.
enum IrohaBlake3 {
    private static let blockBytes = 64
    private static let chunkBytes = 1024
    private static let chunkStart: UInt32 = 1
    private static let chunkEnd: UInt32 = 2
    private static let root: UInt32 = 8
    private static let initialVector: [UInt32] = [
        0x6A09_E667, 0xBB67_AE85, 0x3C6E_F372, 0xA54F_F53A, 0x510E_527F, 0x9B05_688C, 0x1F83_D9AB, 0x5BE0_CD19
    ]
    private static let permutation = [2, 6, 3, 10, 7, 0, 4, 13, 1, 11, 12, 5, 9, 14, 15, 8]

    static func hash(_ input: Data) -> Data? {
        guard input.count <= chunkBytes else {
            return nil
        }
        let bytes = [UInt8](input)
        let blockCount = max(1, (bytes.count + blockBytes - 1) / blockBytes)
        var chainingValue = initialVector
        var output = [UInt32]()
        for blockIndex in 0 ..< blockCount {
            let start = blockIndex * blockBytes
            let end = min(start + blockBytes, bytes.count)
            var block = [UInt8](repeating: 0, count: blockBytes)
            if start < end {
                block.replaceSubrange(0 ..< end - start, with: bytes[start ..< end])
            }
            var flags: UInt32 = blockIndex == 0 ? chunkStart : 0
            if blockIndex == blockCount - 1 {
                flags |= chunkEnd | root
            }
            var words = [UInt32](repeating: 0, count: 16)
            for index in 0 ..< 16 {
                var word: UInt32 = 0
                for shift in 0 ..< 4 {
                    word |= UInt32(block[index * 4 + shift]) << UInt32(8 * shift)
                }
                words[index] = word
            }
            output = compress(chainingValue, words, blockLength: UInt32(end - start), flags: flags)
            chainingValue = Array(output[0 ..< 8])
        }
        var digest = Data()
        for word in chainingValue {
            for shift in 0 ..< 4 {
                digest.append(UInt8(truncatingIfNeeded: word >> UInt32(8 * shift)))
            }
        }
        return digest
    }

    private static func compress(_ chainingValue: [UInt32], _ block: [UInt32], blockLength: UInt32, flags: UInt32) -> [UInt32] {
        var state = chainingValue + Array(initialVector[0 ..< 4]) + [0, 0, blockLength, flags]
        var message = block
        for round in 0 ..< 7 {
            mix(&state, 0, 4, 8, 12, message[0], message[1])
            mix(&state, 1, 5, 9, 13, message[2], message[3])
            mix(&state, 2, 6, 10, 14, message[4], message[5])
            mix(&state, 3, 7, 11, 15, message[6], message[7])
            mix(&state, 0, 5, 10, 15, message[8], message[9])
            mix(&state, 1, 6, 11, 12, message[10], message[11])
            mix(&state, 2, 7, 8, 13, message[12], message[13])
            mix(&state, 3, 4, 9, 14, message[14], message[15])
            if round < 6 {
                message = permutation.map { message[$0] }
            }
        }
        for index in 0 ..< 8 {
            state[index] ^= state[index + 8]
        }
        return state
    }

    private static func mix(
        _ state: inout [UInt32],
        _ first: Int,
        _ second: Int,
        _ third: Int,
        _ fourth: Int,
        _ messageX: UInt32,
        _ messageY: UInt32
    ) {
        state[first] = state[first] &+ state[second] &+ messageX
        state[fourth] = rotateRight(state[fourth] ^ state[first], 16)
        state[third] = state[third] &+ state[fourth]
        state[second] = rotateRight(state[second] ^ state[third], 12)
        state[first] = state[first] &+ state[second] &+ messageY
        state[fourth] = rotateRight(state[fourth] ^ state[first], 8)
        state[third] = state[third] &+ state[fourth]
        state[second] = rotateRight(state[second] ^ state[third], 7)
    }

    private static func rotateRight(_ value: UInt32, _ count: UInt32) -> UInt32 {
        (value >> count) | (value << (32 - count))
    }
}

enum IrohaBase58 {
    private static let alphabet = Array("123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz")

    static func encode(_ data: Data) -> String {
        var value = BigUInt(data)
        var output = [Character]()
        while value > 0 {
            let (quotient, remainder) = value.quotientAndRemainder(dividingBy: 58)
            output.append(alphabet[Int(remainder)])
            value = quotient
        }
        for byte in data {
            guard byte == 0 else { break }
            output.append("1")
        }
        return String(output.reversed())
    }
}

/// Exact canonical lower-case V1 Bech32m contract addresses (`irohac1…`), as the iroha-js codec accepts them.
enum IrohaContractAddress {
    private static let humanReadablePart = "irohac"
    private static let charset = Array("qpzry9x8gf2tvdw0s3jn54khce6mua7l")
    private static let bech32mConstant: UInt32 = 0x2BC8_30A3
    private static let generators: [UInt32] = [0x3B6A_57B2, 0x2650_8E6D, 0x1EA1_19FA, 0x3D42_33DD, 0x2A14_62B3]

    static func isCanonical(_ value: String) -> Bool {
        let characters = Array(value)
        guard !characters.isEmpty, characters.count <= 90, value == value.lowercased(),
              let separator = characters.lastIndex(of: "1"),
              separator > 0, separator <= 83, separator + 7 <= characters.count,
              String(characters[0 ..< separator]) == humanReadablePart else {
            return false
        }
        var values = [Int]()
        for character in characters[(separator + 1)...] {
            guard let index = charset.firstIndex(of: character) else {
                return false
            }
            values.append(index)
        }
        let expandedPrefix = humanReadablePart.unicodeScalars.map { Int($0.value >> 5) } + [0] +
            humanReadablePart.unicodeScalars.map { Int($0.value & 0x1F) }
        guard polymod(expandedPrefix + values) == bech32mConstant,
              let payload = decodePayload(Array(values.dropLast(6))) else {
            return false
        }
        return payload.count == 29 && payload[0] == 1
    }

    private static func polymod(_ values: [Int]) -> UInt32 {
        var checksum: UInt32 = 1
        for value in values {
            let top = checksum >> 25
            checksum = ((checksum & 0x1FFFFFF) << 5) ^ UInt32(value)
            for index in 0 ..< generators.count where (top >> UInt32(index)) & 1 != 0 {
                checksum ^= generators[index]
            }
        }
        return checksum
    }

    private static func decodePayload(_ values: [Int]) -> [UInt8]? {
        var output = [UInt8]()
        var accumulator = 0
        var bits = 0
        for value in values {
            accumulator = (accumulator << 5) | value
            bits += 5
            while bits >= 8 {
                bits -= 8
                output.append(UInt8((accumulator >> bits) & 0xFF))
            }
            accumulator &= bits == 0 ? 0 : (1 << bits) - 1
        }
        guard bits < 5, bits == 0 || accumulator == 0 else {
            return nil
        }
        return output
    }
}

/// Strict Ed25519 public keys, as Iroha admits them: a canonical compressed point on the curve, not of small
/// order, and in the prime-order subgroup.
enum IrohaEd25519PublicKey {
    private struct Point {
        let x: BigUInt
        let y: BigUInt
        let z: BigUInt
        let t: BigUInt
    }

    private static let prime = (BigUInt(1) << 255) - 19
    private static let curveD = BigUInt("37095705934669439343138083508754565189542113879843219016388785533085940283555", radix: 10)!
    private static let sqrtMinusOne = BigUInt("19681161376707505956807079304988542015446066515923890162744021073123829784752", radix: 10)!
    private static let groupOrder = (BigUInt(1) << 252) + BigUInt("27742317777372353535851937790883648493", radix: 10)!
    private static let identity = Point(x: 0, y: 1, z: 1, t: 0)

    static func isValid(_ key: Data) -> Bool {
        guard key.count == 32, let point = decompress(key) else {
            return false
        }
        return !isIdentity(multiply(point, by: 8)) && isIdentity(multiply(point, by: groupOrder))
    }

    private static func decompress(_ key: Data) -> Point? {
        var bytes = [UInt8](key)
        let sign = bytes[31] >> 7
        bytes[31] &= 0x7F
        let y = BigUInt(Data(bytes.reversed()))
        guard y < prime else {
            return nil
        }
        let ySquared = mul(y, y)
        let u = sub(ySquared, 1)
        let v = add(mul(curveD, ySquared), 1)
        let vCubed = mul(mul(v, v), v)
        let vSeventh = mul(mul(vCubed, vCubed), v)
        var x = mul(mul(u, vCubed), mul(u, vSeventh).power((prime - 5) / 8, modulus: prime))
        let check = mul(v, mul(x, x))
        if check == u {
            // x is a square root of u/v.
        } else if check == sub(0, u) {
            x = mul(x, sqrtMinusOne)
        } else {
            return nil
        }
        if x == 0, sign == 1 {
            return nil
        }
        if UInt8(x & 1) != sign {
            x = sub(0, x)
        }
        return Point(x: x, y: y, z: 1, t: mul(x, y))
    }

    private static func multiply(_ point: Point, by scalar: BigUInt) -> Point {
        var result = identity
        var addend = point
        var remaining = scalar
        while remaining > 0 {
            if remaining & 1 == 1 {
                result = add(result, addend)
            }
            addend = add(addend, addend)
            remaining >>= 1
        }
        return result
    }

    /// Unified extended-coordinate addition for a = -1 (complete, so it also doubles).
    private static func add(_ lhs: Point, _ rhs: Point) -> Point {
        let first = mul(sub(lhs.y, lhs.x), sub(rhs.y, rhs.x))
        let second = mul(add(lhs.y, lhs.x), add(rhs.y, rhs.x))
        let third = mul(mul(lhs.t, rhs.t), mul(2, curveD))
        let fourth = mul(mul(lhs.z, rhs.z), 2)
        let e = sub(second, first)
        let f = sub(fourth, third)
        let g = add(fourth, third)
        let h = add(second, first)
        return Point(x: mul(e, f), y: mul(g, h), z: mul(f, g), t: mul(e, h))
    }

    private static func isIdentity(_ point: Point) -> Bool {
        point.x % prime == 0 && point.y % prime == point.z % prime
    }

    private static func add(_ lhs: BigUInt, _ rhs: BigUInt) -> BigUInt {
        (lhs + rhs) % prime
    }

    private static func sub(_ lhs: BigUInt, _ rhs: BigUInt) -> BigUInt {
        let left = lhs % prime
        let right = rhs % prime
        return left >= right ? left - right : prime - (right - left)
    }

    private static func mul(_ lhs: BigUInt, _ rhs: BigUInt) -> BigUInt {
        (lhs * rhs) % prime
    }
}
