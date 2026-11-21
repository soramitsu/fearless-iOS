import CryptoKit
import Foundation
import SSFUtils

/// Plain Connect frames, the approval preimage and Norito NRT0 envelopes. Connect frames use u64 length
/// prefixes and element-frame every `[u8; 32]` (9 bytes per byte), as Torii decodes and re-encodes them.
enum IrohaConnectWireCodec {
    static let fixedBytes = 32
    static let elementFrameBytes = 9
    static let signatureBytes = 64

    private static let frameKindControl: UInt32 = 0
    private static let frameKindCiphertext: UInt32 = 1
    private static let controlOpen: UInt32 = 0
    private static let controlApprove: UInt32 = 1
    private static let controlReject: UInt32 = 2
    private static let controlClose: UInt32 = 3
    private static let controlPing: UInt32 = 4
    private static let controlPong: UInt32 = 5
    private static let controlServerEvent: UInt32 = 6
    private static let payloadControl: UInt32 = 0
    private static let payloadSignRequestRaw: UInt32 = 1
    private static let payloadSignRequestTransaction: UInt32 = 2
    private static let payloadSignResultOK: UInt32 = 3
    private static let payloadSignResultError: UInt32 = 4
    private static let afterKeyClose: UInt32 = 0
    private static let afterKeyReject: UInt32 = 1
    private static let algorithmEd25519: UInt32 = 0
    private static let approveDomain = Data("iroha-connect|approve|v1".utf8)
    private static let relayAuthDomain = Data("iroha-connect|relay-auth|v1".utf8)
    private static let envelopeTypeName = "iroha_torii_shared::connect::EnvelopeV1"

    // MARK: - Inbound frames

    static func decodeFrame(_ data: Data, sessionID: Data) throws -> IrohaConnectFrame {
        guard !data.isEmpty, data.count <= IrohaConnectLimits.frameBytes else {
            throw IrohaConnectError.invalidFrame("frame size is invalid")
        }
        var reader = IrohaConnectReader(data, label: "frame")
        let sid = try decodeFixed32(reader.readField("sid", maximum: fixedBytes * elementFrameBytes), label: "frame.sid")
        guard sid == sessionID else {
            throw IrohaConnectError.invalidFrame("frame belongs to another session")
        }
        let direction = try decodeDirection(reader.readField("dir", maximum: 4), label: "frame.dir")
        let sequence = try IrohaConnectReader.exactU64(reader.readField("seq", maximum: 8), label: "frame.seq")
        guard sequence > 0 else {
            throw IrohaConnectError.invalidFrame("frame.seq must be positive")
        }
        var kind = IrohaConnectReader(try reader.readField("kind"), label: "frame.kind")
        try reader.done()
        let kindTag = try kind.readU32("tag")
        let body = try kind.readField("body")
        try kind.done()

        if kindTag == frameKindControl {
            return IrohaConnectFrame(direction: direction, sequence: sequence, kind: .control(try decodeControl(body)))
        }
        guard kindTag == frameKindCiphertext else {
            throw IrohaConnectError.invalidFrame("unsupported frame kind \(kindTag)")
        }

        var ciphertext = IrohaConnectReader(body, label: "ciphertext")
        let innerDirection = try decodeDirection(ciphertext.readField("dir", maximum: 4), label: "ciphertext.dir")
        var aeadField = IrohaConnectReader(try ciphertext.readField("aead"), label: "ciphertext.aead")
        try ciphertext.done()
        let aead = try aeadField.readField("bytes")
        try aeadField.done()
        guard innerDirection == direction else {
            throw IrohaConnectError.invalidFrame("ciphertext direction does not match the frame")
        }
        guard !aead.isEmpty else {
            throw IrohaConnectError.invalidFrame("ciphertext is empty")
        }
        return IrohaConnectFrame(direction: direction, sequence: sequence, kind: .ciphertext(aead))
    }

    private static func decodeControl(_ data: Data) throws -> IrohaConnectControl {
        var outer = IrohaConnectReader(data, label: "control")
        let tag = try outer.readU32("tag")
        let body = try outer.readField("body")
        try outer.done()
        var reader = IrohaConnectReader(body, label: "control.body")

        switch tag {
        case controlOpen:
            let appPublicKey = try decodeFixed32(
                reader.readField("app_pk", maximum: fixedBytes * elementFrameBytes),
                label: "app_pk"
            )
            let appMetadata = try decodeAppMetadata(reader.readField("app_meta", maximum: 8192))
            var constraints = IrohaConnectReader(try reader.readField("constraints", maximum: 64), label: "constraints")
            let networkID = try constraints.readField("network_id", maximum: fixedBytes)
            try constraints.done()
            guard networkID.count == fixedBytes, networkID[networkID.count - 1] & 1 == 1 else {
                throw IrohaConnectError.invalidFrame("constraints.network_id must be 32 marked hash bytes")
            }
            let permissionsField = try reader.readField("permissions", maximum: 64 * 1024)
            try reader.done()
            return .open(IrohaConnectOpenFrame(
                appPublicKey: appPublicKey,
                appMetadata: appMetadata,
                networkID: networkID,
                permissions: try decodePermissions(permissionsField),
                permissionsField: permissionsField
            ))
        case controlPing, controlPong:
            let nonce = try decodeNonce(body)
            return tag == controlPing ? .ping(nonce) : .pong(nonce)
        case controlClose:
            let close = try decodeClose(&reader)
            return .close(who: close.who, code: close.code, reason: close.reason, retryable: close.retryable)
        case controlReject:
            let reject = try decodeReject(&reader)
            return .reject(code: reject.code, codeID: reject.codeID, reason: reject.reason)
        case controlServerEvent:
            return .serverEvent
        default:
            throw IrohaConnectError.invalidFrame("the wallet does not accept control tag \(tag)")
        }
    }

    private static func decodeClose(
        _ reader: inout IrohaConnectReader
    ) throws -> (who: IrohaConnectRole, code: UInt16, reason: String, retryable: Bool) {
        let who = try decodeRole(reader.readField("who", maximum: 4), label: "close.who")
        let code = try IrohaConnectReader.exactU16(reader.readField("code", maximum: 2), label: "close.code")
        let reason = try decodeText(reader.readField("reason"), label: "close.reason", maximum: IrohaConnectLimits.reasonBytes)
        let retryable = try decodeBool(reader.readField("retryable", maximum: 1), label: "close.retryable")
        try reader.done()
        return (who, code, reason, retryable)
    }

    private static func decodeReject(
        _ reader: inout IrohaConnectReader
    ) throws -> (code: UInt16, codeID: String, reason: String) {
        let code = try IrohaConnectReader.exactU16(reader.readField("code", maximum: 2), label: "reject.code")
        let codeID = try decodeText(reader.readField("code_id"), label: "reject.code_id", maximum: IrohaConnectLimits.codeBytes)
        let reason = try decodeText(reader.readField("reason"), label: "reject.reason", maximum: IrohaConnectLimits.reasonBytes)
        try reader.done()
        return (code, codeID, reason)
    }

    private static func decodeAppMetadata(_ data: Data) throws -> IrohaConnectAppMetadata? {
        var reader = IrohaConnectReader(data, label: "app_meta")
        let tag = try reader.readU8("tag")
        if tag == 0 {
            try reader.done()
            return nil
        }
        guard tag == 1 else {
            throw IrohaConnectError.invalidFrame("app_meta has an invalid option tag")
        }
        var meta = IrohaConnectReader(try reader.readField("value", maximum: 4096), label: "app_meta.value")
        try reader.done()
        let name = try decodeText(meta.readField("name", maximum: 256), label: "app_meta.name", maximum: IrohaConnectLimits.appNameBytes)
        let url = try decodeOptionText(
            meta.readField("url", maximum: 4096),
            label: "app_meta.url",
            maximum: IrohaConnectLimits.appURLBytes
        )
        let iconHash = try decodeOptionText(
            meta.readField("icon_hash", maximum: 512),
            label: "app_meta.icon_hash",
            maximum: IrohaConnectLimits.iconHashBytes
        )
        try meta.done()
        return IrohaConnectAppMetadata(name: name, url: url, iconHash: iconHash)
    }

    private static func decodePermissions(_ data: Data) throws -> IrohaConnectPermissions? {
        var reader = IrohaConnectReader(data, label: "permissions")
        let tag = try reader.readU8("tag")
        if tag == 0 {
            try reader.done()
            return nil
        }
        guard tag == 1 else {
            throw IrohaConnectError.invalidFrame("permissions has an invalid option tag")
        }
        var value = IrohaConnectReader(try reader.readField("value", maximum: 32 * 1024), label: "permissions.value")
        try reader.done()
        let methods = try decodeStringVector(value.readField("methods", maximum: 16 * 1024), label: "permissions.methods")
        let events = try decodeStringVector(value.readField("events", maximum: 16 * 1024), label: "permissions.events")
        var resourcesOption = IrohaConnectReader(
            try value.readField("resources", maximum: 16 * 1024),
            label: "permissions.resources"
        )
        try value.done()
        let resourcesTag = try resourcesOption.readU8("tag")
        var resources: [String]?
        if resourcesTag == 1 {
            resources = try decodeStringVector(
                resourcesOption.readField("value", maximum: 16 * 1024),
                label: "permissions.resources"
            )
        } else if resourcesTag != 0 {
            throw IrohaConnectError.invalidFrame("permissions.resources has an invalid option tag")
        }
        try resourcesOption.done()
        return IrohaConnectPermissions(methods: methods, events: events, resources: resources)
    }

    private static func decodeStringVector(_ data: Data, label: String) throws -> [String] {
        var reader = IrohaConnectReader(data, label: label)
        let count = try reader.readU64("count")
        guard count <= UInt64(IrohaConnectLimits.permissionEntries) else {
            throw IrohaConnectError.invalidFrame("\(label) has too many entries")
        }
        var values = [String]()
        for index in 0 ..< Int(count) {
            values.append(try decodeText(
                reader.readField("[\(index)]", maximum: IrohaConnectLimits.permissionEntryBytes + 8),
                label: "\(label)[\(index)]",
                maximum: IrohaConnectLimits.permissionEntryBytes
            ))
        }
        try reader.done()
        return values
    }

    private static func decodeNonce(_ body: Data) throws -> UInt64 {
        var reader = IrohaConnectReader(body, label: "heartbeat")
        let nonce = try IrohaConnectReader.exactU64(reader.readField("nonce", maximum: 8), label: "heartbeat.nonce")
        try reader.done()
        return nonce
    }

    private static func decodeFixed32(_ data: Data, label: String) throws -> Data {
        guard data.count == fixedBytes * elementFrameBytes else {
            throw IrohaConnectError.invalidFrame("\(label) must be element-framed")
        }
        var reader = IrohaConnectReader(data, label: label)
        var output = Data(count: fixedBytes)
        for index in 0 ..< fixedBytes {
            let element = try reader.readField("[\(index)]", maximum: 1)
            guard element.count == 1 else {
                throw IrohaConnectError.invalidFrame("\(label)[\(index)] must be one byte")
            }
            output[index] = element[element.startIndex]
        }
        try reader.done()
        guard output.contains(where: { $0 != 0 }) else {
            throw IrohaConnectError.invalidFrame("\(label) must not be all zeroes")
        }
        return output
    }

    private static func decodeText(_ data: Data, label: String, maximum: Int) throws -> String {
        var reader = IrohaConnectReader(data, label: label)
        let value = try reader.readField("utf8", maximum: maximum)
        try reader.done()
        guard let text = String(data: value, encoding: .utf8) else {
            throw IrohaConnectError.invalidFrame("\(label) is not UTF-8")
        }
        guard isDisplayText(text) else {
            throw IrohaConnectError.invalidFrame("\(label) is not display text")
        }
        return text
    }

    private static func decodeOptionText(_ data: Data, label: String, maximum: Int) throws -> String? {
        var reader = IrohaConnectReader(data, label: label)
        let tag = try reader.readU8("tag")
        if tag == 0 {
            try reader.done()
            return nil
        }
        guard tag == 1 else {
            throw IrohaConnectError.invalidFrame("\(label) has an invalid option tag")
        }
        let value = try decodeText(reader.readField("value", maximum: maximum + 8), label: label, maximum: maximum)
        try reader.done()
        return value
    }

    private static func decodeDirection(_ data: Data, label: String) throws -> IrohaConnectDirection {
        let value = try IrohaConnectReader.exactU32(data, label: label)
        guard let direction = IrohaConnectDirection(rawValue: value) else {
            throw IrohaConnectError.invalidFrame("\(label) is not a Connect direction")
        }
        return direction
    }

    private static func decodeRole(_ data: Data, label: String) throws -> IrohaConnectRole {
        let value = try IrohaConnectReader.exactU32(data, label: label)
        guard let role = IrohaConnectRole(rawValue: value) else {
            throw IrohaConnectError.invalidFrame("\(label) is not a Connect role")
        }
        return role
    }

    private static func decodeBool(_ data: Data, label: String) throws -> Bool {
        guard data.count == 1, let byte = data.first, byte <= 1 else {
            throw IrohaConnectError.invalidFrame("\(label) must be one boolean byte")
        }
        return byte == 1
    }

    /// Non-empty, trimmed, and free of C0/C1 control characters.
    static func isDisplayText(_ text: String) -> Bool {
        guard !text.isEmpty,
              let first = text.unicodeScalars.first,
              let last = text.unicodeScalars.last,
              !isJavaScriptWhitespace(first),
              !isJavaScriptWhitespace(last) else {
            return false
        }
        return !text.unicodeScalars.contains { $0.value <= 0x1F || ($0.value >= 0x7F && $0.value <= 0x9F) }
    }

    /// The characters `String.prototype.trim` removes.
    static func isJavaScriptWhitespace(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x09 ... 0x0D, 0x20, 0xA0, 0x1680, 0x2000 ... 0x200A, 0x2028, 0x2029, 0x202F, 0x205F, 0x3000, 0xFEFF:
            return true
        default:
            return false
        }
    }

    // MARK: - Outbound frames

    struct ApprovalInput {
        let sessionID: Data
        let networkID: Data
        let appPublicKey: Data
        let walletPublicKey: Data
        let accountID: String
        /// The Open frame's exact `Option<Permissions>` field.
        let permissionsField: Data
        let relayToken: String
    }

    static func relayAuthHash(sessionID: Data, relayToken: String) -> Data {
        Data(SHA256.hash(data: relayAuthDomain + sessionID + Data(relayToken.utf8)))
    }

    /// The tagged structure the wallet signs with the account key; the app verifies it before deriving keys.
    static func approvalPreimage(_ input: ApprovalInput) throws -> Data {
        guard input.networkID.count == fixedBytes else {
            throw IrohaConnectError.invalidFrame("networkId must be 32 bytes")
        }
        _ = try encodeText(input.accountID, label: "accountId", maximum: IrohaConnectLimits.accountIDBytes)
        let permissions = try unwrapOption(input.permissionsField, label: "permissions")
        var preimage = taggedApprovalField("domain", approveDomain)
        preimage += taggedApprovalField("network_id", input.networkID)
        preimage += taggedApprovalField("constraints", try blake2b256(IrohaConnectNorito.structure([input.networkID])))
        preimage += taggedApprovalField("sid", input.sessionID)
        preimage += taggedApprovalField("app_pk", input.appPublicKey)
        preimage += taggedApprovalField("wallet_pk", input.walletPublicKey)
        preimage += taggedApprovalField("account_id", Data(input.accountID.utf8))
        if let permissions {
            preimage += taggedApprovalField("permissions", try blake2b256(permissions))
        }
        preimage += taggedApprovalField("relay_auth", relayAuthHash(sessionID: input.sessionID, relayToken: input.relayToken))
        return preimage
    }

    static func encodeApproveFrame(
        sessionID: Data,
        sequence: UInt64,
        walletPublicKey: Data,
        accountID: String,
        permissionsField: Data,
        signature: Data
    ) throws -> Data {
        guard signature.count == signatureBytes else {
            throw IrohaConnectError.invalidFrame("approval signature must be 64 bytes")
        }
        _ = try unwrapOption(permissionsField, label: "permissions")
        // The wallet signature is a u32 algorithm plus a counted, element-framed byte sequence.
        let encodedSignature = IrohaConnectNorito.structure([
            IrohaConnectNorito.u32(algorithmEd25519),
            IrohaConnectNorito.u64(UInt64(signature.count)) + IrohaConnectNorito.elementFramed(signature)
        ])
        let body = IrohaConnectNorito.structure([
            try fixed32(walletPublicKey, label: "walletPublicKey"),
            try encodeText(accountID, label: "accountId", maximum: IrohaConnectLimits.accountIDBytes),
            permissionsField,
            Data([0]),
            encodedSignature
        ])
        return try controlFrame(sessionID: sessionID, sequence: sequence, tag: controlApprove, body: body)
    }

    static func encodeRejectFrame(
        sessionID: Data,
        sequence: UInt64,
        code: UInt16,
        codeID: String,
        reason: String
    ) throws -> Data {
        guard let first = codeID.unicodeScalars.first,
              CharacterSet.letters.contains(first), first.isASCII,
              codeID.unicodeScalars.allSatisfy({ $0.isASCII && ($0 == "_" || CharacterSet.alphanumerics.contains($0)) }) else {
            throw IrohaConnectError.invalidFrame("codeId must be an identifier")
        }
        return try controlFrame(
            sessionID: sessionID,
            sequence: sequence,
            tag: controlReject,
            body: IrohaConnectNorito.structure([
                IrohaConnectNorito.u16(code),
                try encodeText(codeID, label: "codeId", maximum: IrohaConnectLimits.codeBytes),
                try encodeText(reason, label: "reason", maximum: IrohaConnectLimits.reasonBytes)
            ])
        )
    }

    static func encodePingFrame(sessionID: Data, sequence: UInt64, nonce: UInt64) throws -> Data {
        try controlFrame(
            sessionID: sessionID,
            sequence: sequence,
            tag: controlPing,
            body: IrohaConnectNorito.structure([IrohaConnectNorito.u64(nonce)])
        )
    }

    static func encodePongFrame(sessionID: Data, sequence: UInt64, nonce: UInt64) throws -> Data {
        try controlFrame(
            sessionID: sessionID,
            sequence: sequence,
            tag: controlPong,
            body: IrohaConnectNorito.structure([IrohaConnectNorito.u64(nonce)])
        )
    }

    private static func encodeFrame(sessionID: Data, sequence: UInt64, kind: Data) throws -> Data {
        guard sequence > 0 else {
            throw IrohaConnectError.invalidFrame("sequence must be a positive integer")
        }
        return IrohaConnectNorito.structure([
            try fixed32(sessionID, label: "sid"),
            IrohaConnectNorito.u32(IrohaConnectDirection.walletToApp.rawValue),
            IrohaConnectNorito.u64(sequence),
            kind
        ])
    }

    private static func controlFrame(sessionID: Data, sequence: UInt64, tag: UInt32, body: Data) throws -> Data {
        try encodeFrame(
            sessionID: sessionID,
            sequence: sequence,
            kind: IrohaConnectNorito.tagged(frameKindControl, IrohaConnectNorito.tagged(tag, body))
        )
    }

    private static func taggedApprovalField(_ tag: String, _ value: Data) -> Data {
        let tagBytes = Data(tag.utf8)
        return IrohaConnectNorito.u16(UInt16(tagBytes.count)) + tagBytes + IrohaConnectNorito.u64(UInt64(value.count)) + value
    }

    private static func unwrapOption(_ data: Data, label: String) throws -> Data? {
        if data == Data([0]) {
            return nil
        }
        var reader = IrohaConnectReader(data, label: label)
        guard try reader.readU8("tag") == 1 else {
            throw IrohaConnectError.invalidFrame("\(label) has an invalid option tag")
        }
        let value = try reader.readField("value")
        try reader.done()
        return value
    }

    private static func fixed32(_ bytes: Data, label: String) throws -> Data {
        guard bytes.count == fixedBytes else {
            throw IrohaConnectError.invalidFrame("\(label) must be \(fixedBytes) bytes")
        }
        return IrohaConnectNorito.elementFramed(bytes)
    }

    private static func encodeText(_ value: String, label: String, maximum: Int) throws -> Data {
        guard isDisplayText(value) else {
            throw IrohaConnectError.invalidFrame("\(label) must be non-empty trimmed text without control characters")
        }
        let bytes = Data(value.utf8)
        guard bytes.count <= maximum else {
            throw IrohaConnectError.invalidFrame("\(label) exceeds \(maximum) UTF-8 bytes")
        }
        return IrohaConnectNorito.field(bytes)
    }

    static func blake2b256(_ data: Data) throws -> Data {
        do {
            return try data.blake2b32()
        } catch {
            throw IrohaConnectError.invalidFrame("blake2b is unavailable")
        }
    }

    // MARK: - Envelopes

    static func openEnvelope(
        keys: IrohaConnectDirectionKeys,
        sessionID: Data,
        sequence: UInt64,
        direction: IrohaConnectDirection,
        aead: Data
    ) throws -> IrohaConnectAppPayload {
        guard direction == .appToWallet else {
            throw IrohaConnectError.invalidFrame("the wallet opens only app ciphertext")
        }
        guard let plaintext = keys.openApp(aead, sessionID: sessionID, sequence: sequence) else {
            throw IrohaConnectError.invalidFrame("ciphertext does not authenticate")
        }
        var envelope = IrohaConnectReader(try unframeNorito(plaintext), label: "envelope")
        let envelopeSequence = try IrohaConnectReader.exactU64(envelope.readField("seq", maximum: 8), label: "envelope.seq")
        let payload = try envelope.readField("payload")
        try envelope.done()
        guard envelopeSequence == sequence else {
            throw IrohaConnectError.invalidFrame("envelope sequence does not match the frame")
        }
        return try decodeAppPayload(payload)
    }

    static func sealEnvelope(
        keys: IrohaConnectDirectionKeys,
        sessionID: Data,
        sequence: UInt64,
        payload: IrohaConnectWalletPayload
    ) throws -> Data {
        let plaintext = frameNorito(IrohaConnectNorito.structure([
            IrohaConnectNorito.u64(sequence),
            try encodeWalletPayload(payload)
        ]))
        guard let aead = keys.sealWallet(plaintext, sessionID: sessionID, sequence: sequence) else {
            throw IrohaConnectError.invalidFrame("envelope could not be sealed")
        }
        return try encodeFrame(
            sessionID: sessionID,
            sequence: sequence,
            kind: IrohaConnectNorito.tagged(
                frameKindCiphertext,
                IrohaConnectNorito.structure([
                    IrohaConnectNorito.u32(IrohaConnectDirection.walletToApp.rawValue),
                    IrohaConnectNorito.field(aead)
                ])
            )
        )
    }

    private static func decodeAppPayload(_ data: Data) throws -> IrohaConnectAppPayload {
        var reader = IrohaConnectReader(data, label: "payload")
        let tag = try reader.readU32("tag")
        switch tag {
        case payloadSignRequestTransaction:
            let transaction = try decodeBytesField(
                reader.readField("tx_bytes"),
                label: "tx_bytes",
                maximum: IrohaConnectLimits.transactionBytes
            )
            try reader.done()
            return .signRequestTransaction(transaction)
        case payloadSignRequestRaw:
            let domainTag = try decodeText(
                reader.readField("domain_tag"),
                label: "domain_tag",
                maximum: IrohaConnectLimits.domainTagBytes
            )
            let bytes = try decodeBytesField(reader.readField("bytes"), label: "bytes", maximum: IrohaConnectLimits.rawBytes)
            try reader.done()
            return .signRequestRaw(domainTag: domainTag, bytes: bytes)
        case payloadControl:
            let control = try reader.readField("control")
            try reader.done()
            return try decodeAfterKeyControl(control)
        default:
            return .unknown(tag: tag)
        }
    }

    private static func decodeAfterKeyControl(_ data: Data) throws -> IrohaConnectAppPayload {
        var reader = IrohaConnectReader(data, label: "payload.control")
        let tag = try reader.readU32("tag")
        switch tag {
        case afterKeyClose:
            let close = try decodeClose(&reader)
            return .close(who: close.who, code: close.code, reason: close.reason, retryable: close.retryable)
        case afterKeyReject:
            let reject = try decodeReject(&reader)
            return .reject(code: reject.code, codeID: reject.codeID, reason: reject.reason)
        default:
            return .unknown(tag: payloadControl)
        }
    }

    private static func decodeBytesField(_ data: Data, label: String, maximum: Int) throws -> Data {
        var reader = IrohaConnectReader(data, label: label)
        let value = try reader.readField("bytes", maximum: maximum)
        try reader.done()
        return value
    }

    private static func encodeWalletPayload(_ payload: IrohaConnectWalletPayload) throws -> Data {
        switch payload {
        case let .signResultOK(signature):
            guard signature.count == signatureBytes else {
                throw IrohaConnectError.invalidFrame("signature must be 64 bytes")
            }
            return IrohaConnectNorito.u32(payloadSignResultOK) + IrohaConnectNorito.field(
                IrohaConnectNorito.structure([Data([UInt8(algorithmEd25519)]), IrohaConnectNorito.field(signature)])
            )
        case let .signResultError(code, message):
            return IrohaConnectNorito.u32(payloadSignResultError) +
                IrohaConnectNorito.field(try encodeText(code, label: "code", maximum: IrohaConnectLimits.codeBytes)) +
                IrohaConnectNorito.field(try encodeText(message, label: "message", maximum: IrohaConnectLimits.reasonBytes))
        case let .close(code, reason, retryable):
            return IrohaConnectNorito.u32(payloadControl) + IrohaConnectNorito.field(
                IrohaConnectNorito.u32(afterKeyClose) +
                    IrohaConnectNorito.field(IrohaConnectNorito.u32(IrohaConnectRole.wallet.rawValue)) +
                    IrohaConnectNorito.field(IrohaConnectNorito.u16(code)) +
                    IrohaConnectNorito.field(try encodeText(reason, label: "reason", maximum: IrohaConnectLimits.reasonBytes)) +
                    IrohaConnectNorito.field(Data([retryable ? 1 : 0]))
            )
        }
    }

    // MARK: - Norito NRT0

    static let envelopeSchemaHash = Data(SHA256.hash(data: Data("norito:v1:type-name\0\(envelopeTypeName)".utf8)))
        .prefix(16)

    static func frameNorito(_ payload: Data, schemaHash: Data = envelopeSchemaHash, flags: UInt8 = 0) -> Data {
        var output = Data("NRT0".utf8)
        output += Data([0, 0])
        output += schemaHash
        output += Data([0])
        output += IrohaConnectNorito.u64(UInt64(payload.count))
        output += IrohaConnectNorito.u64(IrohaConnectNorito.crc64(payload))
        output += Data([flags])
        output += payload
        return output
    }

    private static func unframeNorito(_ data: Data) throws -> Data {
        let bytes = [UInt8](data)
        guard bytes.count >= 40, bytes[0 ..< 4] == [0x4E, 0x52, 0x54, 0x30] else {
            throw IrohaConnectError.invalidFrame("envelope is not an NRT0 frame")
        }
        guard bytes[4] == 0, bytes[5] == 0 else {
            throw IrohaConnectError.invalidFrame("envelope uses an unsupported Norito version")
        }
        guard Data(bytes[6 ..< 22]) == envelopeSchemaHash else {
            throw IrohaConnectError.invalidFrame("envelope schema does not match")
        }
        guard bytes[22] == 0, bytes[39] == 0 else {
            throw IrohaConnectError.invalidFrame("envelope uses unsupported layout flags")
        }
        var header = IrohaConnectReader(Data(bytes[23 ..< 39]), label: "envelope.header")
        let length = try header.readU64("length")
        let checksum = try header.readU64("crc64")
        guard length == UInt64(bytes.count - 40) else {
            throw IrohaConnectError.invalidFrame("envelope length does not match")
        }
        let payload = Data(bytes[40...])
        guard IrohaConnectNorito.crc64(payload) == checksum else {
            throw IrohaConnectError.invalidFrame("envelope checksum does not match")
        }
        return payload
    }
}

/// Little-endian Norito encoding helpers for Connect frames (u64 length prefixes).
enum IrohaConnectNorito {
    static func u16(_ value: UInt16) -> Data {
        withUnsafeBytes(of: value.littleEndian) { Data($0) }
    }

    static func u32(_ value: UInt32) -> Data {
        withUnsafeBytes(of: value.littleEndian) { Data($0) }
    }

    static func u64(_ value: UInt64) -> Data {
        withUnsafeBytes(of: value.littleEndian) { Data($0) }
    }

    static func field(_ payload: Data) -> Data {
        u64(UInt64(payload.count)) + payload
    }

    static func structure(_ fields: [Data]) -> Data {
        fields.reduce(into: Data()) { $0 += field($1) }
    }

    static func tagged(_ tag: UInt32, _ body: Data) -> Data {
        u32(tag) + u64(UInt64(body.count)) + body
    }

    static func elementFramed(_ bytes: Data) -> Data {
        var output = Data(count: bytes.count * IrohaConnectWireCodec.elementFrameBytes)
        for (index, byte) in bytes.enumerated() {
            let offset = index * IrohaConnectWireCodec.elementFrameBytes
            output[offset] = 1
            output[offset + 8] = byte
        }
        return output
    }

    private static let crc64Table: [UInt64] = (0 ..< 256).map { index -> UInt64 in
        var crc = UInt64(index)
        for _ in 0 ..< 8 {
            crc = crc & 1 == 1 ? (crc >> 1) ^ 0xC96C_5795_D787_0F42 : crc >> 1
        }
        return crc
    }

    /// CRC-64/XZ (ECMA-182 reflected), the checksum in every Norito NRT0 header.
    static func crc64(_ data: Data) -> UInt64 {
        var crc = UInt64.max
        for byte in data {
            crc = crc64Table[Int((crc ^ UInt64(byte)) & 0xFF)] ^ (crc >> 8)
        }
        return crc ^ UInt64.max
    }
}

/// A bounds-checked little-endian reader over one Connect structure.
struct IrohaConnectReader {
    private let bytes: [UInt8]
    private let label: String
    private var offset = 0

    init(_ data: Data, label: String) {
        bytes = [UInt8](data)
        self.label = label
    }

    static func exact(_ data: Data, width: Int, label: String) throws -> IrohaConnectReader {
        guard data.count == width else {
            throw IrohaConnectError.invalidFrame("\(label) must be \(width) bytes")
        }
        return IrohaConnectReader(data, label: label)
    }

    static func exactU16(_ data: Data, label: String) throws -> UInt16 {
        var reader = try exact(data, width: 2, label: label)
        return try reader.readU16(label)
    }

    static func exactU32(_ data: Data, label: String) throws -> UInt32 {
        var reader = try exact(data, width: 4, label: label)
        return try reader.readU32(label)
    }

    static func exactU64(_ data: Data, label: String) throws -> UInt64 {
        var reader = try exact(data, width: 8, label: label)
        return try reader.readU64(label)
    }

    var remaining: Int {
        bytes.count - offset
    }

    mutating func readBytes(_ count: Int, _ name: String) throws -> Data {
        guard count >= 0, count <= remaining else {
            throw IrohaConnectError.invalidFrame("\(label).\(name) is truncated")
        }
        defer { offset += count }
        return Data(bytes[offset ..< offset + count])
    }

    mutating func readU8(_ name: String) throws -> UInt8 {
        try readBytes(1, name)[0]
    }

    mutating func readU16(_ name: String) throws -> UInt16 {
        try readBytes(2, name).withUnsafeBytes { UInt16(littleEndian: $0.loadUnaligned(as: UInt16.self)) }
    }

    mutating func readU32(_ name: String) throws -> UInt32 {
        try readBytes(4, name).withUnsafeBytes { UInt32(littleEndian: $0.loadUnaligned(as: UInt32.self)) }
    }

    mutating func readU64(_ name: String) throws -> UInt64 {
        try readBytes(8, name).withUnsafeBytes { UInt64(littleEndian: $0.loadUnaligned(as: UInt64.self)) }
    }

    mutating func readField(_ name: String, maximum: Int = IrohaConnectLimits.frameBytes) throws -> Data {
        let length = try readU64("\(name).length")
        guard length <= UInt64(maximum) else {
            throw IrohaConnectError.invalidFrame("\(label).\(name) exceeds \(maximum) bytes")
        }
        return try readBytes(Int(length), name)
    }

    func done() throws {
        guard remaining == 0 else {
            throw IrohaConnectError.invalidFrame("\(label) has trailing bytes")
        }
    }
}
