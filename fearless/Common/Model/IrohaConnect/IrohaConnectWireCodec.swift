import CryptoKit
import Foundation

enum IrohaConnectWireCodec {
    static let maximumFrameSize = 131_072
    static let maximumSigningMessageSize = 32768

    private static let maximumControlSize = 65536
    private static let maximumCiphertextSize = 65536
    private static let maximumStringSize = 512
    private static let maximumCollectionCount = 16
    private static let envelopeTypeName = "iroha_torii_shared::connect::EnvelopeV1"

    static func decodeFrame(_ data: Data) throws -> IrohaConnectFrame {
        guard data.count <= maximumFrameSize else {
            throw IrohaConnectError.invalidLength
        }

        var cursor = IrohaConnectCursor(data)
        let sessionID = try cursor.readField(maximumLength: 32)
        guard sessionID.count == 32 else {
            throw IrohaConnectError.invalidLength
        }
        let direction = try decodeDirection(try cursor.readField(maximumLength: 4))
        let sequence = try decodeUInt64(try cursor.readField(maximumLength: 8))
        guard sequence > 0 else {
            throw IrohaConnectError.invalidSequence
        }
        let kindBytes = try cursor.readField(maximumLength: maximumFrameSize)
        try cursor.expectEnd()

        var kindCursor = IrohaConnectCursor(kindBytes)
        let kindTag = try kindCursor.readUInt32()
        let bodyLength = try kindCursor.readLength(maximum: maximumFrameSize)
        let body = try kindCursor.read(bodyLength)
        try kindCursor.expectEnd()

        let kind: IrohaConnectFrame.Kind
        switch kindTag {
        case 0:
            kind = .control(try decodeControl(body))
        case 1:
            kind = .ciphertext(try decodeCiphertext(body, outerDirection: direction))
        default:
            throw IrohaConnectError.unsupportedFrameKind
        }

        return IrohaConnectFrame(
            sessionID: sessionID,
            direction: direction,
            sequence: sequence,
            kind: kind
        )
    }

    static func encodeApprovalFrame(
        sessionID: Data,
        sequence: UInt64,
        walletPublicKey: Data,
        accountID: String,
        permissions: IrohaConnectPermissions,
        signature: Data
    ) throws -> Data {
        guard sessionID.count == 32,
              sequence > 0,
              walletPublicKey.count == 32,
              signature.count == 64,
              !accountID.isEmpty,
              accountID.utf8.count <= maximumStringSize else {
            throw IrohaConnectError.invalidLength
        }

        let body = encodeStruct([
            walletPublicKey,
            encodeString(accountID),
            encodeOption(encodePermissionsValue(permissions)),
            Data([0]),
            encodeWalletSignature(signature)
        ])
        let control = encodeUInt32(1) + encodeUInt64(UInt64(body.count)) + body
        return try encodeControlFrame(
            sessionID: sessionID,
            direction: .walletToApp,
            sequence: sequence,
            control: control
        )
    }

    static func encodePongFrame(
        sessionID: Data,
        sequence: UInt64,
        nonce: UInt64
    ) throws -> Data {
        let body = encodeStruct([encodeUInt64(nonce)])
        let control = encodeUInt32(5) + encodeUInt64(UInt64(body.count)) + body
        return try encodeControlFrame(
            sessionID: sessionID,
            direction: .walletToApp,
            sequence: sequence,
            control: control
        )
    }

    static func decodeSignRawEnvelope(
        _ plaintext: Data,
        expectedSequence: UInt64
    ) throws -> IrohaConnectSignRawRequest {
        let encodedEnvelope = try decodeNoritoFrame(plaintext)
        var envelope = IrohaConnectCursor(encodedEnvelope)
        let sequence = try decodeUInt64(try envelope.readField(maximumLength: 8))
        let payload = try envelope.readField(maximumLength: maximumSigningMessageSize + 1024)
        try envelope.expectEnd()
        guard sequence == expectedSequence else {
            throw IrohaConnectError.invalidSequence
        }

        var payloadCursor = IrohaConnectCursor(payload)
        guard try payloadCursor.readUInt32() == 1 else {
            throw IrohaConnectError.unsupportedRequest
        }
        let domain = try decodeString(
            try payloadCursor.readField(maximumLength: maximumStringSize + 8),
            maximumLength: maximumStringSize
        )
        let message = try decodeNestedBytes(
            try payloadCursor.readField(maximumLength: maximumSigningMessageSize + 8),
            maximumLength: maximumSigningMessageSize
        )
        try payloadCursor.expectEnd()

        return IrohaConnectSignRawRequest(domain: domain, message: message)
    }

    static func encodeSignResultEnvelope(sequence: UInt64, signature: Data) throws -> Data {
        guard sequence > 0, signature.count == 64 else {
            throw IrohaConnectError.invalidSignature
        }

        let payload = encodeUInt32(3) + encodeField(encodeWalletSignature(signature))
        return encodeNoritoFrame(encodeStruct([encodeUInt64(sequence), payload]))
    }

    static func encodeCiphertextFrame(
        sessionID: Data,
        sequence: UInt64,
        ciphertext: Data
    ) throws -> Data {
        guard sessionID.count == 32,
              sequence > 0,
              ciphertext.count <= maximumCiphertextSize else {
            throw IrohaConnectError.invalidLength
        }

        let body = encodeStruct([
            encodeUInt32(IrohaConnectDirection.walletToApp.rawValue),
            encodeBytes(ciphertext)
        ])
        let kind = encodeUInt32(1) + encodeUInt64(UInt64(body.count)) + body
        return encodeStruct([
            sessionID,
            encodeUInt32(IrohaConnectDirection.walletToApp.rawValue),
            encodeUInt64(sequence),
            kind
        ])
    }

    static func encodePermissionsValue(_ permissions: IrohaConnectPermissions) -> Data {
        encodeStruct([
            encodeStringVector(permissions.methods),
            encodeStringVector(permissions.events),
            encodeOption(permissions.resources.map(encodeStringVector))
        ])
    }

    static func encodeConstraints(networkID: Data) -> Data {
        encodeStruct([networkID])
    }

    private static func decodeControl(_ data: Data) throws -> IrohaConnectControlFrame {
        guard data.count <= maximumControlSize else {
            throw IrohaConnectError.invalidLength
        }

        var cursor = IrohaConnectCursor(data)
        let tag = try cursor.readUInt32()
        let bodyLength = try cursor.readLength(maximum: maximumControlSize)
        let body = try cursor.read(bodyLength)
        try cursor.expectEnd()

        switch tag {
        case 0:
            return .open(try decodeOpen(body))
        case 4:
            return .ping(try decodeNonceControl(body))
        case 5:
            return .pong(try decodeNonceControl(body))
        default:
            throw IrohaConnectError.unsupportedControl
        }
    }

    private static func decodeOpen(_ data: Data) throws -> IrohaConnectOpenFrame {
        var cursor = IrohaConnectCursor(data)
        let appPublicKey = try cursor.readField(maximumLength: 32)
        guard appPublicKey.count == 32 else {
            throw IrohaConnectError.invalidLength
        }
        let appMetadata = try decodeAppMetadata(try cursor.readField(maximumLength: 2048))

        let constraintBytes = try cursor.readField(maximumLength: 48)
        var constraints = IrohaConnectCursor(constraintBytes)
        let networkID = try constraints.readField(maximumLength: 32)
        guard networkID.count == 32 else {
            throw IrohaConnectError.invalidLength
        }
        try constraints.expectEnd()

        let permissions = try decodePermissionsOption(
            try cursor.readField(maximumLength: maximumControlSize)
        )
        try cursor.expectEnd()

        return IrohaConnectOpenFrame(
            appPublicKey: appPublicKey,
            appMetadata: appMetadata,
            networkID: networkID,
            permissions: permissions
        )
    }

    private static func decodeAppMetadata(_ data: Data) throws -> IrohaConnectAppMetadata? {
        guard let value = try decodeOption(data, maximumLength: 2048) else {
            return nil
        }

        var cursor = IrohaConnectCursor(value)
        let name = try decodeString(
            try cursor.readField(maximumLength: maximumStringSize + 8),
            maximumLength: maximumStringSize
        )
        guard !name.isEmpty,
              name == name.trimmingCharacters(in: .whitespacesAndNewlines),
              name.utf8.count <= 128 else {
            throw IrohaConnectError.invalidLength
        }
        let urlLiteral = try decodeOptionalString(
            try cursor.readField(maximumLength: maximumStringSize + 16)
        )
        let iconHash = try decodeOptionalString(
            try cursor.readField(maximumLength: maximumStringSize + 16)
        )
        try cursor.expectEnd()

        let url: URL?
        if let urlLiteral {
            guard let components = URLComponents(string: urlLiteral),
                  components.scheme == "https",
                  components.host != nil,
                  components.user == nil,
                  components.password == nil,
                  let parsedURL = components.url else {
                throw IrohaConnectError.invalidURI
            }
            url = parsedURL
        } else {
            url = nil
        }

        return IrohaConnectAppMetadata(name: name, url: url, iconHash: iconHash)
    }

    private static func decodeOptionalString(_ data: Data) throws -> String? {
        guard let value = try decodeOption(data, maximumLength: maximumStringSize + 8) else {
            return nil
        }
        let string = try decodeString(value, maximumLength: maximumStringSize)
        guard !string.isEmpty,
              string == string.trimmingCharacters(in: .whitespacesAndNewlines) else {
            throw IrohaConnectError.invalidLength
        }
        return string
    }

    private static func decodePermissionsOption(_ data: Data) throws -> IrohaConnectPermissions? {
        guard let value = try decodeOption(data, maximumLength: maximumControlSize) else {
            return nil
        }

        var cursor = IrohaConnectCursor(value)
        let methods = try decodeStringVector(
            try cursor.readField(maximumLength: maximumControlSize)
        )
        let events = try decodeStringVector(
            try cursor.readField(maximumLength: maximumControlSize)
        )
        let resourcesData = try cursor.readField(maximumLength: maximumControlSize)
        let resources = try decodeOption(resourcesData, maximumLength: maximumControlSize)
            .map { try decodeStringVector($0) }
        try cursor.expectEnd()

        return IrohaConnectPermissions(methods: methods, events: events, resources: resources)
    }

    private static func decodeStringVector(_ data: Data) throws -> [String] {
        var cursor = IrohaConnectCursor(data)
        let count = try cursor.readLength(maximum: maximumCollectionCount)
        var values = [String]()
        values.reserveCapacity(count)
        for _ in 0 ..< count {
            values.append(
                try decodeString(
                    try cursor.readField(maximumLength: maximumStringSize + 8),
                    maximumLength: maximumStringSize
                )
            )
        }
        try cursor.expectEnd()
        return values
    }

    private static func decodeCiphertext(
        _ data: Data,
        outerDirection: IrohaConnectDirection
    ) throws -> Data {
        var cursor = IrohaConnectCursor(data)
        let direction = try decodeDirection(try cursor.readField(maximumLength: 4))
        let ciphertext = try decodeNestedBytes(
            try cursor.readField(maximumLength: maximumCiphertextSize + 8),
            maximumLength: maximumCiphertextSize
        )
        try cursor.expectEnd()
        guard direction == outerDirection else {
            throw IrohaConnectError.invalidDirection
        }
        return ciphertext
    }

    private static func decodeNonceControl(_ data: Data) throws -> UInt64 {
        var cursor = IrohaConnectCursor(data)
        let nonce = try decodeUInt64(try cursor.readField(maximumLength: 8))
        try cursor.expectEnd()
        return nonce
    }

    private static func encodeControlFrame(
        sessionID: Data,
        direction: IrohaConnectDirection,
        sequence: UInt64,
        control: Data
    ) throws -> Data {
        guard sessionID.count == 32,
              sequence > 0,
              control.count <= maximumControlSize else {
            throw IrohaConnectError.invalidLength
        }
        let kind = encodeUInt32(0) + encodeUInt64(UInt64(control.count)) + control
        return encodeStruct([
            sessionID,
            encodeUInt32(direction.rawValue),
            encodeUInt64(sequence),
            kind
        ])
    }

    private static func encodeWalletSignature(_ signature: Data) -> Data {
        encodeStruct([Data([0]), encodeBytes(signature)])
    }

    private static func encodeStringVector(_ values: [String]) -> Data {
        encodeUInt64(UInt64(values.count)) + values.reduce(into: Data()) { result, value in
            result.append(encodeField(encodeString(value)))
        }
    }

    private static func encodeString(_ value: String) -> Data {
        encodeBytes(Data(value.utf8))
    }

    private static func encodeBytes(_ value: Data) -> Data {
        encodeField(value)
    }

    private static func encodeOption(_ value: Data?) -> Data {
        guard let value else {
            return Data([0])
        }
        return Data([1]) + encodeField(value)
    }

    private static func encodeStruct(_ fields: [Data]) -> Data {
        fields.reduce(into: Data()) { result, field in
            result.append(encodeField(field))
        }
    }

    private static func encodeField(_ value: Data) -> Data {
        encodeUInt64(UInt64(value.count)) + value
    }

    private static func decodeDirection(_ data: Data) throws -> IrohaConnectDirection {
        guard let direction = IrohaConnectDirection(rawValue: try decodeUInt32(data)) else {
            throw IrohaConnectError.invalidDirection
        }
        return direction
    }

    private static func decodeUInt32(_ data: Data) throws -> UInt32 {
        var cursor = IrohaConnectCursor(data)
        let value = try cursor.readUInt32()
        try cursor.expectEnd()
        return value
    }

    private static func decodeUInt64(_ data: Data) throws -> UInt64 {
        var cursor = IrohaConnectCursor(data)
        let value = try cursor.readUInt64()
        try cursor.expectEnd()
        return value
    }

    private static func decodeNestedBytes(_ data: Data, maximumLength: Int) throws -> Data {
        var cursor = IrohaConnectCursor(data)
        let value = try cursor.readField(maximumLength: maximumLength)
        try cursor.expectEnd()
        return value
    }

    private static func decodeString(_ data: Data, maximumLength: Int) throws -> String {
        let bytes = try decodeNestedBytes(data, maximumLength: maximumLength)
        guard let value = String(data: bytes, encoding: .utf8) else {
            throw IrohaConnectError.invalidUTF8
        }
        return value
    }

    private static func decodeOption(_ data: Data, maximumLength: Int) throws -> Data? {
        var cursor = IrohaConnectCursor(data)
        let tag = try cursor.read(1)
        if tag == Data([0]) {
            try cursor.expectEnd()
            return nil
        }
        guard tag == Data([1]) else {
            throw IrohaConnectError.invalidLength
        }
        let value = try cursor.readField(maximumLength: maximumLength)
        try cursor.expectEnd()
        return value
    }

    private static func encodeNoritoFrame(_ payload: Data) -> Data {
        Data("NRT0".utf8) +
            Data([0, 0]) +
            noritoSchemaHash() +
            Data([0]) +
            encodeUInt64(UInt64(payload.count)) +
            encodeUInt64(crc64(payload)) +
            Data([0]) +
            payload
    }

    private static func decodeNoritoFrame(_ data: Data) throws -> Data {
        guard data.count >= 40,
              data.prefix(4) == Data("NRT0".utf8),
              data[4] == 0,
              data[5] == 0,
              data.subdata(in: 6 ..< 22) == noritoSchemaHash(),
              data[22] == 0,
              data[39] == 0 else {
            throw IrohaConnectError.authenticationFailed
        }

        var cursor = IrohaConnectCursor(data.subdata(in: 23 ..< data.count))
        let payloadLength = try cursor.readLength(maximum: maximumFrameSize)
        let expectedCRC = try cursor.readUInt64()
        _ = try cursor.read(1)
        let payload = try cursor.read(payloadLength)
        try cursor.expectEnd()
        guard crc64(payload) == expectedCRC else {
            throw IrohaConnectError.authenticationFailed
        }
        return payload
    }

    private static func noritoSchemaHash() -> Data {
        Data(SHA256.hash(
            data: Data("norito:v1:type-name\0\(envelopeTypeName)".utf8)
        )).prefix(16)
    }

    private static func crc64(_ data: Data) -> UInt64 {
        let polynomial: UInt64 = 0xC96C_5795_D787_0F42
        var crc = UInt64.max
        for byte in data {
            var tableValue = (crc ^ UInt64(byte)) & 0xFF
            for _ in 0 ..< 8 {
                tableValue = tableValue & 1 == 1 ? (tableValue >> 1) ^ polynomial : tableValue >> 1
            }
            crc = tableValue ^ (crc >> 8)
        }
        return crc ^ UInt64.max
    }

    private static func encodeUInt32(_ value: UInt32) -> Data {
        var littleEndian = value.littleEndian
        return Data(bytes: &littleEndian, count: MemoryLayout<UInt32>.size)
    }

    private static func encodeUInt64(_ value: UInt64) -> Data {
        var littleEndian = value.littleEndian
        return Data(bytes: &littleEndian, count: MemoryLayout<UInt64>.size)
    }
}

private struct IrohaConnectCursor {
    private let data: Data
    private var offset = 0

    init(_ data: Data) {
        self.data = data
    }

    mutating func read(_ count: Int) throws -> Data {
        guard count >= 0, count <= data.count - offset else {
            throw IrohaConnectError.truncated
        }
        defer { offset += count }
        return data.subdata(in: offset ..< offset + count)
    }

    mutating func readUInt32() throws -> UInt32 {
        let bytes = try read(MemoryLayout<UInt32>.size)
        return bytes.withUnsafeBytes { raw in
            UInt32(littleEndian: raw.loadUnaligned(as: UInt32.self))
        }
    }

    mutating func readUInt64() throws -> UInt64 {
        let bytes = try read(MemoryLayout<UInt64>.size)
        return bytes.withUnsafeBytes { raw in
            UInt64(littleEndian: raw.loadUnaligned(as: UInt64.self))
        }
    }

    mutating func readLength(maximum: Int) throws -> Int {
        let value = try readUInt64()
        guard value <= UInt64(maximum), value <= UInt64(Int.max) else {
            throw IrohaConnectError.invalidLength
        }
        return Int(value)
    }

    mutating func readField(maximumLength: Int) throws -> Data {
        let length = try readLength(maximum: maximumLength)
        return try read(length)
    }

    func expectEnd() throws {
        guard offset == data.count else {
            throw IrohaConnectError.trailingBytes
        }
    }
}
