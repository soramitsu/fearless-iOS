import Foundation
import CommonWallet
import IrohaCrypto

enum WalletQREncoderError: Error {
    case accountIdMismatch
    case brokenData
}

enum WalletQRDecoderError: Error {
    case brokenFormat
    case unexpectedNumberOfFields
    case undefinedPrefix
    case accountIdMismatch
}

private extension Data {
    func checkAccountId(_ accountId: Data) -> Bool {
        if accountId == self {
            return true
        }

        return accountId == (try? self.blake2b32())
    }
}

final class WalletQREncoder: WalletQREncoderProtocol {
    let username: String?
    let networkType: SNAddressType
    let publicKey: Data
    let prefix: String
    let separator: String

    private lazy var addressFactory = SS58AddressFactory()

    init(networkType: SNAddressType, publicKey: Data, username: String?, prefix: String, separator: String) {
        self.networkType = networkType
        self.publicKey = publicKey
        self.prefix = prefix
        self.username = username
        self.separator = separator
    }

    func encode(receiverInfo: ReceiveInfo) throws -> Data {
        let accountId = try Data(hexString: receiverInfo.accountId)

        guard publicKey.checkAccountId(accountId) else {
            throw WalletQREncoderError.accountIdMismatch
        }

        let address = try addressFactory.address(fromPublicKey: AccountIdWrapper(rawData: accountId),
                                                 type: networkType)

        var fields: [String] = [
            prefix,
            address,
            publicKey.toHex(includePrefix: true)
        ]

        if let username = username {
            fields.append(username)
        }

        guard let data = fields.joined(separator: separator).data(using: .utf8) else {
            throw WalletQREncoderError.brokenData
        }

        return data
    }
}

final class WalletQRDecoder: WalletQRDecoderProtocol {
    let networkType: SNAddressType
    let prefix: String
    let separator: String

    private lazy var addressFactory = SS58AddressFactory()

    init(networkType: SNAddressType, prefix: String, separator: String) {
        self.networkType = networkType
        self.prefix = prefix
        self.separator = separator
    }

    func decode(data: Data) throws -> ReceiveInfo {
        guard let fields = String(data: data, encoding: .utf8)?
            .components(separatedBy: separator) else {
            throw WalletQRDecoderError.brokenFormat
        }

        guard fields.count >= 3 else {
            throw WalletQRDecoderError.unexpectedNumberOfFields
        }

        guard fields[0] == prefix else {
            throw WalletQRDecoderError.undefinedPrefix
        }

        let accountId = try addressFactory.accountId(fromAddress: fields[1], type: networkType)
        let publicKey = try Data(hexString: fields[2])

        guard publicKey.checkAccountId(accountId) else {
            throw WalletQRDecoderError.accountIdMismatch
        }

        return ReceiveInfo(accountId: accountId.toHex(),
                           assetId: nil,
                           amount: nil,
                           details: nil)
    }
}

struct WalletQRCoderConstants {
    static let prefix: String = "substrate"
    static let fieldsSeparator: String = ":"
}

final class WalletQRCoderFactory: WalletQRCoderFactoryProtocol {
    let networkType: SNAddressType
    let publicKey: Data
    let username: String?

    init(networkType: SNAddressType, publicKey: Data, username: String?) {
        self.networkType = networkType
        self.publicKey = publicKey
        self.username = username
    }

    func createEncoder() -> WalletQREncoderProtocol {
        WalletQREncoder(networkType: networkType,
                        publicKey: publicKey,
                        username: username,
                        prefix: WalletQRCoderConstants.prefix,
                        separator: WalletQRCoderConstants.fieldsSeparator)
    }

    func createDecoder() -> WalletQRDecoderProtocol {
        WalletQRDecoder(networkType: networkType,
                        prefix: WalletQRCoderConstants.prefix,
                        separator: WalletQRCoderConstants.fieldsSeparator)
    }
}
