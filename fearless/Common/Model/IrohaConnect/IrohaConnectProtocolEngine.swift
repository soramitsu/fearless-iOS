import CryptoKit
import Foundation
import SSFUtils

final class IrohaConnectProtocolEngine {
    let handoff: IrohaConnectWalletURI
    let walletEphemeralPublicKey: Data

    private enum State {
        case awaitingOpen
        case open(IrohaConnectPermissions)
        case approved(signingPublicKey: Data)
        case pending(signingPublicKey: Data, request: IrohaConnectSignRawRequest)
    }

    private let crypto: IrohaConnectCryptoContext
    private var state = State.awaitingOpen
    private var nextAppSequence: UInt64 = 1
    private var nextWalletSequence: UInt64 = 1

    init(
        handoff: IrohaConnectWalletURI,
        ephemeralPrivateKey: Data? = nil
    ) throws {
        self.handoff = handoff
        crypto = try IrohaConnectCryptoContext(
            handoff: handoff,
            ephemeralPrivateKey: ephemeralPrivateKey
        )
        walletEphemeralPublicKey = crypto.walletPublicKey
    }

    func acceptOpenFrame(_ data: Data) throws -> IrohaConnectOpenFrame {
        guard case .awaitingOpen = state else {
            throw IrohaConnectError.invalidState
        }
        let frame = try validatedInboundFrame(data)
        guard frame.direction == .appToWallet,
              frame.sequence == nextAppSequence,
              case let .control(.open(open)) = frame.kind else {
            throw IrohaConnectError.invalidSequence
        }
        guard open.appPublicKey == handoff.appPublicKey,
              open.networkID == handoff.networkID.bytes else {
            throw IrohaConnectError.sessionIDMismatch
        }
        guard open.permissions == .uranaiContractSigning else {
            throw IrohaConnectError.invalidPermissions
        }

        nextAppSequence += 1
        state = .open(.uranaiContractSigning)
        return open
    }

    func makeApprovalPreimage(
        accountID: String,
        signingPublicKey: Data
    ) throws -> Data {
        guard case let .open(permissions) = state else {
            throw IrohaConnectError.invalidState
        }
        try validateAccount(accountID, signingPublicKey: signingPublicKey)

        let constraints = IrohaConnectWireCodec.encodeConstraints(
            networkID: handoff.networkID.bytes
        )
        let encodedPermissions = IrohaConnectWireCodec.encodePermissionsValue(permissions)
        let constraintsHash: Data
        let permissionsHash: Data
        do {
            constraintsHash = try constraints.blake2b32()
            permissionsHash = try encodedPermissions.blake2b32()
        } catch {
            throw IrohaConnectError.cryptographyFailed
        }

        let relayHash = Data(SHA256.hash(
            data: Data("iroha-connect|relay-auth|v1".utf8) +
                handoff.sessionID +
                Data(handoff.relayToken.utf8)
        ))
        return taggedField("domain", value: Data("iroha-connect|approve|v1".utf8)) +
            taggedField("network_id", value: handoff.networkID.bytes) +
            taggedField("constraints", value: constraintsHash) +
            taggedField("sid", value: handoff.sessionID) +
            taggedField("app_pk", value: handoff.appPublicKey) +
            taggedField("wallet_pk", value: walletEphemeralPublicKey) +
            taggedField("account_id", value: Data(accountID.utf8)) +
            taggedField("permissions", value: permissionsHash) +
            taggedField("relay_auth", value: relayHash)
    }

    func makeApprovalFrame(
        accountID: String,
        signingPublicKey: Data,
        signature: Data
    ) throws -> Data {
        let preimage = try makeApprovalPreimage(
            accountID: accountID,
            signingPublicKey: signingPublicKey
        )
        guard signature.count == 64 else {
            throw IrohaConnectError.invalidSignature
        }
        do {
            let publicKey = try Curve25519.Signing.PublicKey(
                rawRepresentation: signingPublicKey
            )
            guard publicKey.isValidSignature(signature, for: preimage) else {
                throw IrohaConnectError.invalidSignature
            }
        } catch let error as IrohaConnectError {
            throw error
        } catch {
            throw IrohaConnectError.invalidSignature
        }

        guard case let .open(permissions) = state else {
            throw IrohaConnectError.invalidState
        }
        let frame = try IrohaConnectWireCodec.encodeApprovalFrame(
            sessionID: handoff.sessionID,
            sequence: nextWalletSequence,
            walletPublicKey: walletEphemeralPublicKey,
            accountID: accountID,
            permissions: permissions,
            signature: signature
        )
        nextWalletSequence += 1
        state = .approved(signingPublicKey: signingPublicKey)
        return frame
    }

    func decryptSignRawRequest(_ data: Data) throws -> IrohaConnectSignRawRequest {
        guard case let .approved(signingPublicKey) = state else {
            throw IrohaConnectError.invalidState
        }
        let frame = try validatedInboundFrame(data)
        guard frame.direction == .appToWallet,
              frame.sequence == nextAppSequence,
              case let .ciphertext(ciphertext) = frame.kind else {
            throw IrohaConnectError.invalidSequence
        }

        let plaintext = try crypto.decryptAppCiphertext(
            ciphertext,
            sequence: frame.sequence
        )
        let request = try IrohaConnectWireCodec.decodeSignRawEnvelope(
            plaintext,
            expectedSequence: frame.sequence
        )
        guard request.domain == IrohaConnectPermissions.contractCallSignatureDomain else {
            throw IrohaConnectError.invalidPermissions
        }
        guard request.message.count <= IrohaConnectWireCodec.maximumSigningMessageSize else {
            throw IrohaConnectError.messageTooLarge
        }

        nextAppSequence += 1
        state = .pending(signingPublicKey: signingPublicKey, request: request)
        return request
    }

    func makeSignResultFrame(signature: Data) throws -> Data {
        guard case let .pending(signingPublicKey, request) = state else {
            throw IrohaConnectError.invalidState
        }
        guard signature.count == 64 else {
            throw IrohaConnectError.invalidSignature
        }
        do {
            let publicKey = try Curve25519.Signing.PublicKey(
                rawRepresentation: signingPublicKey
            )
            guard publicKey.isValidSignature(signature, for: request.message) else {
                throw IrohaConnectError.invalidSignature
            }
        } catch let error as IrohaConnectError {
            throw error
        } catch {
            throw IrohaConnectError.invalidSignature
        }

        let plaintext = try IrohaConnectWireCodec.encodeSignResultEnvelope(
            sequence: nextWalletSequence,
            signature: signature
        )
        let ciphertext = try crypto.encryptWalletPlaintext(
            plaintext,
            sequence: nextWalletSequence
        )
        let frame = try IrohaConnectWireCodec.encodeCiphertextFrame(
            sessionID: handoff.sessionID,
            sequence: nextWalletSequence,
            ciphertext: ciphertext
        )
        nextWalletSequence += 1
        state = .approved(signingPublicKey: signingPublicKey)
        return frame
    }

    func makePongFrame(for data: Data) throws -> Data {
        guard case .awaitingOpen = state else {
            let frame = try validatedInboundFrame(data)
            guard frame.direction == .appToWallet,
                  frame.sequence == nextAppSequence,
                  case let .control(.ping(nonce)) = frame.kind else {
                throw IrohaConnectError.invalidSequence
            }
            let response = try IrohaConnectWireCodec.encodePongFrame(
                sessionID: handoff.sessionID,
                sequence: nextWalletSequence,
                nonce: nonce
            )
            nextAppSequence += 1
            nextWalletSequence += 1
            return response
        }
        throw IrohaConnectError.invalidState
    }

    private func validatedInboundFrame(_ data: Data) throws -> IrohaConnectFrame {
        let frame = try IrohaConnectWireCodec.decodeFrame(data)
        guard frame.sessionID == handoff.sessionID else {
            throw IrohaConnectError.sessionIDMismatch
        }
        return frame
    }

    private func validateAccount(_ accountID: String, signingPublicKey: Data) throws {
        guard signingPublicKey.count == 32,
              !accountID.isEmpty,
              accountID == accountID.trimmingCharacters(in: .whitespacesAndNewlines),
              accountID.utf8.count <= 512,
              let details = try? IrohaAddressCodec.parse(accountID),
              details.publicKeyHex.lowercased() == signingPublicKey.irohaConnectHex else {
            throw IrohaConnectError.invalidAccount
        }
    }

    private func taggedField(_ tag: String, value: Data) -> Data {
        let tagBytes = Data(tag.utf8)
        return littleEndian(UInt16(tagBytes.count)) +
            tagBytes +
            littleEndian(UInt64(value.count)) +
            value
    }

    private func littleEndian<T: FixedWidthInteger>(_ value: T) -> Data {
        var encoded = value.littleEndian
        return Data(bytes: &encoded, count: MemoryLayout<T>.size)
    }
}

private extension Data {
    var irohaConnectHex: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
