import Foundation
import CommonWallet
import IrohaCrypto
import FearlessUtils

final class WalletQREncoder: WalletQREncoderProtocol {
    let username: String?
    let addressPrefix: UInt16
    let publicKey: Data

    private lazy var substrateEncoder = AddressQREncoder()
    private lazy var addressFactory = SS58AddressFactory()

    init(addressPrefix: UInt16, publicKey: Data, username: String?) {
        self.addressPrefix = addressPrefix
        self.publicKey = publicKey
        self.username = username
    }

    func encode(receiverInfo: ReceiveInfo) throws -> Data {
        let accountId = try Data(hexString: receiverInfo.accountId)

        let address = try addressFactory.address(
            fromAccountId: accountId,
            type: addressPrefix
        )

        let info = AddressQRInfo(
            address: address,
            rawPublicKey: publicKey,
            username: username
        )
        return try substrateEncoder.encode(info: info)
    }
}

final class WalletQRDecoder: WalletQRDecoderProtocol {
    private let qrDecoders: [QRDecodable]
    private let asset: AssetModel
    private let addressPrefix: UInt16

    init(addressPrefix: UInt16, asset: AssetModel) {
        qrDecoders = [
            AddressQRDecoder(chainType: addressPrefix),
            CexQRDecoder()
        ]
        self.asset = asset
        self.addressPrefix = addressPrefix
    }

    func decode(data: Data) throws -> ReceiveInfo {
        let info = qrDecoders.compactMap {
            try? $0.decode(data: data)
        }.first

        guard let info = info else {
            throw QRDecoderError.wrongDecoder
        }

        let chainFormat: ChainFormat = info.address.hasPrefix("0x")
            ? .ethereum
            : .substrate(addressPrefix)

        let accountId = try info.address.toAccountId(using: chainFormat)

        return ReceiveInfo(
            accountId: accountId.toHex(includePrefix: info.address.hasPrefix("0x")),
            assetId: asset.id,
            amount: nil,
            details: nil
        )
    }
}

final class WalletQRCoderFactory: WalletQRCoderFactoryProtocol {
    let addressPrefix: UInt16
    let publicKey: Data
    let username: String?
    let asset: AssetModel

    init(addressPrefix: UInt16, publicKey: Data, username: String?, asset: AssetModel) {
        self.addressPrefix = addressPrefix
        self.publicKey = publicKey
        self.username = username
        self.asset = asset
    }

    func createEncoder() -> WalletQREncoderProtocol {
        WalletQREncoder(
            addressPrefix: addressPrefix,
            publicKey: publicKey,
            username: username
        )
    }

    func createDecoder() -> WalletQRDecoderProtocol {
        WalletQRDecoder(addressPrefix: addressPrefix, asset: asset)
    }
}
