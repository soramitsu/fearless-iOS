import Foundation
import CommonWallet
import IrohaCrypto
import FearlessUtils

final class WalletQREncoder: WalletQREncoderProtocol {
    let username: String?
    let addressPrefix: UInt16
    let publicKey: Data

    private lazy var substrateEncoder = SubstrateQREncoder()
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

        let info = SubstrateQRInfo(
            address: address,
            rawPublicKey: publicKey,
            username: username
        )
        return try substrateEncoder.encode(info: info)
    }
}

final class WalletQRDecoder: WalletQRDecoderProtocol {
    private lazy var addressFactory = SS58AddressFactory()
    private let substrateDecoder: SubstrateQRDecoder
    private let asset: AssetModel

    init(addressPrefix: UInt16, asset: AssetModel) {
        substrateDecoder = SubstrateQRDecoder(chainType: addressPrefix)
        self.asset = asset
    }

    func decode(data: Data) throws -> ReceiveInfo {
        let info = try substrateDecoder.decode(data: data)

        let accountId = try addressFactory.accountId(
            fromAddress: info.address,
            type: substrateDecoder.chainType
        )

        return ReceiveInfo(
            accountId: accountId.toHex(),
            assetId: asset.identifier,
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
