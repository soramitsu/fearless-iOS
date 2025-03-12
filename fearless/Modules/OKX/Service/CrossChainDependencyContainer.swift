import SSFModels
import Web3
import SoraKeystore
import Foundation

final class CrossChainDependencyContainer {
    private let okxService: OKXDexAggregatorService
    private let wallet: MetaAccountModel

    init(
        okxService: OKXDexAggregatorService,
        wallet: MetaAccountModel
    ) {
        self.okxService = okxService
        self.wallet = wallet
    }

    func getOkxDataFetcher(for okxCase: OKXCase) throws -> OKXDataFetching {
        switch okxCase {
        case let .swap(chainAsset):
            let eth = try EthereumNodeFetching().getHttps(for: chainAsset.chain)
            let ethereumService = BaseEthereumService(ws: eth)
            return OKXSwapsDataFetching(okxService: okxService, wallet: wallet, ethereumService: ethereumService)
        case .bridge:
            return OKXCrossChainDataFetching(
                okxService: okxService,
                wallet: wallet
            )
        }
    }
    
    func getEthereumSwapService(for chainAsset: ChainAsset) -> OKXEthereumSwapService? {
        guard
            let eth = try? EthereumNodeFetching().getHttps(for: chainAsset.chain),
            let accountResponse = wallet.fetch(for: chainAsset.chain.accountRequest()),
            let senderAddress = accountResponse.toAddress(),
            let privateKey = try? CrossChainDependencyContainer.fetchSecretKey(for: chainAsset.chain, accountResponse: accountResponse, wallet: wallet),
            let ethereumPrivateKey = try? EthereumPrivateKey(privateKey: privateKey.bytes)
        else {
            return nil
        }
        
        let swapService = OKXEthereumSwapServiceImpl(
            privateKey: ethereumPrivateKey,
            senderAddress: senderAddress,
            eth: eth
        )
        
        return swapService
    }
    
    private static func fetchSecretKey(
        for chain: ChainModel,
        accountResponse: ChainAccountResponse,
        wallet: MetaAccountModel
    ) throws -> Data {
        let accountId = accountResponse.isChainAccount ? accountResponse.accountId : nil
        let tag: String = chain.isEthereumBased
            ? KeystoreTagV2.ethereumSecretKeyTagForMetaId(wallet.metaId, accountId: accountId)
            : KeystoreTagV2.substrateSecretKeyTagForMetaId(wallet.metaId, accountId: accountId)

        let keystore = Keychain()
        let secretKey = try keystore.fetchKey(for: tag)
        return secretKey
    }
}
