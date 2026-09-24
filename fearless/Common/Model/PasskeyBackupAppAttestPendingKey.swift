import Foundation
import Security

/// The server's short-lived, wallet-proof-bound bootstrap ceremony context.
/// A new nonce for another subject or ceremony must never inherit a pending Apple key.
struct PasskeyBackupAppAttestChallenge: CustomStringConvertible {
    let nonce: PasskeyBackupServerAttestationNonce
    let ceremonyID: String
    let subject: String
    let expiresAtSeconds: Int64

    init(serverNonce: String, ceremonyID: String, subject: String, expiresAt: Date) throws {
        guard ceremonyID.range(of: #"\Aceremony\.[A-Za-z0-9_-]{16,128}\z"#, options: .regularExpression) != nil,
              subject.range(of: #"\Aowner:[A-Za-z0-9_-]{16,128}\z"#, options: .regularExpression) != nil,
              expiresAt.timeIntervalSince1970.isFinite,
              expiresAt.timeIntervalSince1970.rounded(.down) == expiresAt.timeIntervalSince1970,
              expiresAt.timeIntervalSince1970 > 0,
              expiresAt.timeIntervalSince1970 < Double(Int64.max) else {
            throw PasskeyBackupAppAttestError.invalidServerNonce
        }
        nonce = try PasskeyBackupServerAttestationNonce(base64URL: serverNonce)
        self.ceremonyID = ceremonyID
        self.subject = subject
        expiresAtSeconds = Int64(expiresAt.timeIntervalSince1970)
    }

    func validate(now: Date) throws {
        let remaining = Double(expiresAtSeconds) - now.timeIntervalSince1970
        guard remaining > 0, remaining <= 120 else {
            throw PasskeyBackupAppAttestError.challengeExpired
        }
    }

    var description: String {
        "PasskeyBackupAppAttestChallenge(<redacted>)"
    }
}

struct PasskeyBackupPendingAppAttestation {
    let appleKeyID: String
    let challenge: PasskeyBackupAppAttestChallenge

    init(appleKeyID: String, challenge: PasskeyBackupAppAttestChallenge) throws {
        guard let bytes = Data(base64Encoded: appleKeyID), bytes.count == 32,
              bytes.base64EncodedString() == appleKeyID else {
            throw PasskeyBackupAppAttestError.invalidKeyID
        }
        self.appleKeyID = appleKeyID
        self.challenge = challenge
    }

    func matches(_ candidate: PasskeyBackupAppAttestChallenge) -> Bool {
        challenge.ceremonyID == candidate.ceremonyID && challenge.subject == candidate.subject &&
            challenge.expiresAtSeconds == candidate.expiresAtSeconds &&
            challenge.nonce.bytes == candidate.nonce.bytes &&
            challenge.nonce.clientDataHash == candidate.nonce.clientDataHash
    }
}

@MainActor
protocol PasskeyBackupPendingAttestationStore {
    func load() throws -> PasskeyBackupPendingAppAttestation?
    func save(_ pending: PasskeyBackupPendingAppAttestation) throws
    func clear() throws
}

/// Device-only journal for the Apple key ID, never wallet material or an attestation private key.
@MainActor
final class KeychainPendingAppAttestationStore: PasskeyBackupPendingAttestationStore {
    private let service: String
    private let account: String

    init(
        service: String = "jp.co.soramitsu.fearlesswallet.passkey-app-attest-pending.v1",
        account: String = "first-owner-bootstrap"
    ) {
        self.service = service
        self.account = account
    }

    private var query: [CFString: Any] {
        [kSecClass: kSecClassGenericPassword, kSecAttrService: service, kSecAttrAccount: account]
    }

    func load() throws -> PasskeyBackupPendingAppAttestation? {
        var search = query
        search[kSecReturnData] = true
        search[kSecMatchLimit] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(search as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess, let bytes = result as? Data,
              let plist = try? PropertyListSerialization.propertyList(from: bytes, format: nil),
              let fields = plist as? [String: Any], Set(fields.keys) ==
              Set(["version", "keyID", "nonce", "ceremonyID", "subject", "expiresAt"]),
              fields["version"] as? Int == 1,
              let keyID = fields["keyID"] as? String,
              let nonce = fields["nonce"] as? String,
              let ceremonyID = fields["ceremonyID"] as? String,
              let subject = fields["subject"] as? String,
              let expiresAt = fields["expiresAt"] as? Int64,
              let challenge = try? PasskeyBackupAppAttestChallenge(
                  serverNonce: nonce, ceremonyID: ceremonyID, subject: subject,
                  expiresAt: Date(timeIntervalSince1970: Double(expiresAt))
              ),
              let pending = try? PasskeyBackupPendingAppAttestation(
                  appleKeyID: keyID, challenge: challenge
              ) else { throw PasskeyBackupAppAttestError.storageUnavailable }
        return pending
    }

    func save(_ pending: PasskeyBackupPendingAppAttestation) throws {
        let fields: [String: Any] = [
            "version": 1, "keyID": pending.appleKeyID,
            "nonce": PasskeyBackupServerAttestationNonce.base64URL(pending.challenge.nonce.bytes),
            "ceremonyID": pending.challenge.ceremonyID, "subject": pending.challenge.subject,
            "expiresAt": pending.challenge.expiresAtSeconds
        ]
        let bytes: Data
        do {
            bytes = try PropertyListSerialization.data(
                fromPropertyList: fields, format: .binary, options: 0
            )
        } catch { throw PasskeyBackupAppAttestError.storageUnavailable }
        var attributes = query
        attributes[kSecValueData] = bytes
        attributes[kSecAttrAccessible] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let status = SecItemAdd(attributes as CFDictionary, nil)
        if status == errSecDuplicateItem {
            guard SecItemUpdate(query as CFDictionary, [kSecValueData: bytes] as CFDictionary) == errSecSuccess
            else { throw PasskeyBackupAppAttestError.storageUnavailable }
        } else if status != errSecSuccess {
            throw PasskeyBackupAppAttestError.storageUnavailable
        }
    }

    func clear() throws {
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw PasskeyBackupAppAttestError.storageUnavailable
        }
    }
}
