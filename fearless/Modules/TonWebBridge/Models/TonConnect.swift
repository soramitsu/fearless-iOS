import Foundation
import TonSwift

struct Info: Encodable {
    let isWalletBrowser: Bool
    let deviceInfo: TonConnect.DeviceInfo
    let protocolVersion: Int
}

enum TonConnect {}

extension TonConnect {
    enum ConnectEvent: Encodable {
        case success(ConnectEventSuccess)
        case error(ConnectEventError)
    }

    struct DeviceInfo: Encodable {
        let platform = "iphone"
        let appName = "Fearless"
        let appVersion = AppVersion.stringValue
        let maxProtocolVersion = 2
        let features = [
            FeatureCompatible.legacy(Feature()),
            FeatureCompatible.feature(Feature())
        ]

        enum FeatureCompatible: Encodable {
            case feature(Feature)
            case legacy(Feature)

            func encode(to encoder: Encoder) throws {
                var container = encoder.singleValueContainer()
                switch self {
                case let .feature(feature):
                    try container.encode(feature)
                case let .legacy(feature):
                    try container.encode(feature.name)
                }
            }
        }

        struct Feature: Encodable {
            let name = "SendTransaction"
            let maxMessages = 4
        }

        init() {}
    }

    struct ConnectEventSuccess: Encodable {
        struct Payload: Encodable {
            let items: [ConnectItemReply]
            let device: DeviceInfo
        }

        let event = "connect"
        let id = Int(Date().timeIntervalSince1970)
        let payload: Payload
    }

    struct ConnectEventError: Encodable {
        struct Payload: Encodable {
            let code: Error
            let message: String
        }

        enum Error: Int, Encodable, Swift.Error {
            case unknownError = 0
            case badRequest = 1
            case appManifestNotFound = 2
            case appManifestContentError = 3
            case unknownApp = 100
            case userDeclinedTheConnection = 300
        }

        let event = "connect_error"
        let id = Int(Date().timeIntervalSince1970)
        let payload: Payload
    }

    enum ConnectItemReply: Encodable {
        case tonAddress(TonAddressItemReply)
        case tonProof(TonProofItemReply)
    }

    struct TonAddressItemReply: Encodable {
        let name = "ton_addr"
        let address: TonSwift.Address
        let network: Int16
        let publicKey: TonSwift.PublicKey
        let walletStateInit: TonSwift.StateInit
    }

    enum TonProofItemReply: Encodable {
        case success(TonProofItemReplySuccess)
        case error(TonProofItemReplyError)
    }

    struct TonProofItemReplySuccess: Encodable {
        struct Proof: Encodable {
            let timestamp: UInt64
            let domain: Domain
            let signature: Signature
            let payload: String
            let privateKey: PrivateKey
        }

        struct Signature: Encodable {
            let address: TonSwift.Address
            let domain: Domain
            let timestamp: UInt64
            let payload: String
        }

        struct Domain: Encodable {
            let lengthBytes: UInt32
            let value: String
        }

        let name = "ton_proof"
        let proof: Proof
    }

    struct TonProofItemReplyError: Encodable {
        struct Error: Encodable {
            let message: String?
            let code: ErrorCode
        }

        enum ErrorCode: Int, Encodable {
            case unknownError = 0
            case methodNotSupported = 400
        }

        let name = "ton_proof"
        let error: Error
    }
}

extension TonConnect.TonProofItemReplySuccess {
    init(
        address: TonSwift.Address,
        domain: String,
        payload: String,
        privateKey: PrivateKey
    ) {
        let timestamp = UInt64(Date().timeIntervalSince1970)
        let domain = Domain(domain: domain)
        let signature = Signature(
            address: address,
            domain: domain,
            timestamp: timestamp,
            payload: payload
        )
        let proof = Proof(
            timestamp: timestamp,
            domain: domain,
            signature: signature,
            payload: payload,
            privateKey: privateKey
        )

        self.init(proof: proof)
    }
}

extension TonConnect.TonProofItemReplySuccess.Domain {
    init(domain: String) {
        let domainLength = UInt32(domain.utf8.count)
        value = domain
        lengthBytes = domainLength
    }
}

extension TonConnect {
    enum SendTransactionResponse {
        case success(SendTransactionResponseSuccess)
        case error(SendTransactionResponseError)
    }

    struct SendTransactionResponseSuccess: Encodable {
        let result: String
        let id: String
    }

    struct SendTransactionResponseError: Encodable {
        struct Error: Encodable {
            let code: ErrorCode
            let message: String
        }

        enum ErrorCode: Int, Encodable, Swift.Error {
            case unknownError = 0
            case badRequest = 1
            case unknownApp = 10
            case userDeclinedTransaction = 300
            case methodNotSupported = 400
        }

        let id: String
        let error: Error

        init(id: String, error: Error) {
            self.id = id
            self.error = error
        }
    }
}
