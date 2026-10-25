import Foundation
import SSFModels

struct ChainAccountRequest {
    let chainId: ChainModel.Id
    let addressPrefix: UInt16
    let isEthereumBased: Bool
    let accountId: AccountId?
}

enum ChainAccountFetchingError: Error {
    case accountNotExists
}

extension ChainAccountResponse {
    func toAddress() -> AccountAddress? {
        let chainFormat: SFChainFormat = isEthereumBased ? .sfEthereum : .sfSubstrate(addressPrefix)
        return try? accountId.toAddress(using: chainFormat)
    }

    func chainFormat() -> SFChainFormat {
        isEthereumBased ? .sfEthereum : .sfSubstrate(addressPrefix)
    }
}

extension MetaAccountModel {
    func fetch(for request: ChainAccountRequest) -> ChainAccountResponse? {
        if let chainAccount = chainAccounts.first(where: { $0.chainId == request.chainId }) {
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

    func fetchChainAccountFor(chain: ChainModel, address: String) throws -> ChainAccountResponse? {
        let nativeChainAccount = fetch(for: chain.accountRequest())
        if let nativeAddress = nativeChainAccount?.toAddress(), nativeAddress == address {
            return nativeChainAccount
        }

        for chainAccount in chainAccounts {
            let chainFormat: SFChainFormat = chainAccount
                .ethereumBased ? .sfEthereum : .sfSubstrate(chain.addressPrefix)
            if let chainAddress = try? chainAccount.accountId.toAddress(using: chainFormat),
               chainAddress == address
            {
                let account = ChainAccountResponse(
                    chainId: chain.chainId,
                    accountId: chainAccount.accountId,
                    publicKey: chainAccount.publicKey,
                    name: name,
                    cryptoType: CryptoType(rawValue: substrateCryptoType) ?? .sr25519,
                    addressPrefix: chain.addressPrefix,
                    isEthereumBased: chainAccount.ethereumBased,
                    isChainAccount: true,
                    walletId: metaId
                )
                return account
            }
        }
        return nil
    }
}
