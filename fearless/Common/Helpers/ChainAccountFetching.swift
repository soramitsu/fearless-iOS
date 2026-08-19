import Foundation
import SSFModels

struct ChainAccountResponse: Equatable {
    let chainId: ChainModel.Id
    let accountId: AccountId
    let publicKey: Data
    let name: String
    let cryptoType: CryptoType
    let addressPrefix: UInt16
    let isEthereumBased: Bool
    let isChainAccount: Bool
    let walletId: String
}

enum ChainAccountFetchingError: Error {
    case accountNotExists
}

extension ChainAccountResponse {
    func toDisplayAddress() throws -> DisplayAddress {
        let address = try displayAddress()

        return DisplayAddress(address: address, username: name)
    }

    func toAddress() -> AccountAddress? {
        try? displayAddress()
    }

    func chainFormat() -> ChainFormat {
        isEthereumBased ? .ethereum : .substrate(addressPrefix)
    }

    private func displayAddress() throws -> AccountAddress {
        if UniversalWalletChainAccountSupport.isUniversalWalletChain(chainId) {
            guard let address = UniversalWalletChainAccountSupport.address(for: chainId, publicKey: publicKey) else {
                throw ChainAccountFetchingError.accountNotExists
            }

            return address
        }

        let chainFormat: ChainFormat = isEthereumBased ? .ethereum : .substrate(addressPrefix)
        return try accountId.toAddress(using: chainFormat)
    }
}

extension MetaAccountModel {
    func fetch(for request: ChainAccountRequest) -> ChainAccountResponse? {
        if let chainAccount = chainAccounts.first(where: {
            guard UniversalWalletChainAccountSupport.chainId(
                $0.chainId,
                matches: request.chainId
            ) else {
                return false
            }
            if UniversalWalletChainAccountSupport.chainId(
                request.chainId,
                matches: UniversalWalletRegistry.taira.chainId
            ) {
                return UniversalWalletChainAccountSupport.isValidTairaAccount($0)
            }
            return true
        }) {
            guard let cryptoType = CryptoType(rawValue: chainAccount.cryptoType) else {
                return nil
            }

            return ChainAccountResponse(
                chainId: request.chainId,
                accountId: chainAccount.accountId,
                publicKey: chainAccount.publicKey,
                name: name,
                cryptoType: cryptoType,
                addressPrefix: request.addressPrefix,
                isEthereumBased: request.isEthereumBased,
                isChainAccount: true,
                walletId: metaId
            )
        }

        guard !UniversalWalletChainAccountSupport.isUniversalWalletChain(request.chainId) else {
            return nil
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
                cryptoType: .ecdsa,
                addressPrefix: request.addressPrefix,
                isEthereumBased: request.isEthereumBased,
                isChainAccount: false,
                walletId: metaId
            )
        }

        guard let cryptoType = CryptoType(rawValue: substrateCryptoType) else {
            return nil
        }

        return ChainAccountResponse(
            chainId: request.chainId,
            accountId: substrateAccountId,
            publicKey: substratePublicKey,
            name: name,
            cryptoType: cryptoType,
            addressPrefix: request.addressPrefix,
            isEthereumBased: false,
            isChainAccount: false,
            walletId: metaId
        )
    }
}
