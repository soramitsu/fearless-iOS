import Foundation

struct ChainAccountRequest {
    let chainId: ChainModel.Id
    let addressPrefix: UInt16
    let isEthereumBased: Bool
}

struct ChainAccountResponse {
    let chainId: ChainModel.Id
    let accountId: AccountId
    let publicKey: Data
    let name: String
    let cryptoType: MultiassetCryptoType
    let addressPrefix: UInt16
    let isEthereumBased: Bool
}

enum ChainAccountFetchingError: Error {
    case accountNotExists
}

extension ChainAccountResponse {
    func toAccountItem() throws -> AccountItem {
        let chainFormat: ChainFormat = isEthereumBased ? .ethereum : .substrate(addressPrefix)
        let address = try accountId.toAddress(using: chainFormat)
        let cryptoType = CryptoType(rawValue: cryptoType.rawValue) ?? .ecdsa

        return AccountItem(
            address: address,
            cryptoType: cryptoType,
            username: name,
            publicKeyData: publicKey
        )
    }
}

extension MetaAccountModel {
    func fetch(for request: ChainAccountRequest) -> ChainAccountResponse? {
        if let chainAccount = chainAccounts.first(where: { $0.chainId == request.chainId }) {
            guard let cryptoType = MultiassetCryptoType(rawValue: chainAccount.cryptoType) else {
                return nil
            }

            return ChainAccountResponse(
                chainId: request.chainId,
                accountId: chainAccount.accountId,
                publicKey: chainAccount.publicKey,
                name: name,
                cryptoType: cryptoType,
                addressPrefix: request.addressPrefix,
                isEthereumBased: request.isEthereumBased
            )
        }

        if request.isEthereumBased {
            guard let publicKey = ethereumPublicKey, let accountId = ethereumAddress else {
                return nil
            }

            return ChainAccountResponse(
                chainId: request.chainId,
                accountId: accountId,
                publicKey: publicKey,
                name: name,
                cryptoType: MultiassetCryptoType.ethereumEcdsa,
                addressPrefix: request.addressPrefix,
                isEthereumBased: request.isEthereumBased
            )
        }

        guard let cryptoType = MultiassetCryptoType(rawValue: substrateCryptoType) else {
            return nil
        }

        return ChainAccountResponse(
            chainId: request.chainId,
            accountId: substrateAccountId,
            publicKey: substratePublicKey,
            name: name,
            cryptoType: cryptoType,
            addressPrefix: request.addressPrefix,
            isEthereumBased: false
        )
    }
}

extension ChainModel {
    func accountRequest() -> ChainAccountRequest {
        ChainAccountRequest(
            chainId: chainId,
            addressPrefix: addressPrefix,
            isEthereumBased: isEthereumBased
        )
    }
}
