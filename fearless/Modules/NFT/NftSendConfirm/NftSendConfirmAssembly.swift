import UIKit
import SoraFoundation
import SSFUtils
import SSFModels
import SoraKeystore
import Web3

final class NftSendConfirmAssembly {
    static func configureModule(
        wallet: MetaAccountModel,
        nft: NFT,
        receiverAddress: String,
        scamInfo: ScamInfo?
    ) -> NftSendConfirmModuleCreationResult? {
        do {
            let localizationManager = LocalizationManager.shared
            let accountViewModelFactory = AccountViewModelFactory(iconGenerator: PolkadotIconGenerator())
            let transferService = try createTransferService(for: nft.chain, wallet: wallet)

            let interactor = NftSendConfirmInteractor(transferService: transferService)
            let router = NftSendConfirmRouter()

            let presenter = NftSendConfirmPresenter(
                interactor: interactor,
                router: router,
                localizationManager: localizationManager,
                scamInfo: scamInfo,
                receiverAddress: receiverAddress,
                wallet: wallet,
                accountViewModelFactory: accountViewModelFactory,
                nft: nft,
                logger: Logger.shared,
                nftViewModelFactory: NftSendConfirmViewModelFactory()
            )

            let view = NftSendConfirmViewController(
                output: presenter,
                localizationManager: localizationManager
            )

            return (view, presenter)
        } catch {
            Logger.shared.error(error.localizedDescription)
            return nil
        }
    }

    private static func createTransferService(for chain: ChainModel, wallet: MetaAccountModel) throws -> NftTransferService {
        guard let accountResponse = wallet.fetch(for: chain.accountRequest()) else {
            throw ChainAccountFetchingError.accountNotExists
        }
        let keystore = Keychain()

        switch chain.chainBaseType {
        case .substrate:
            throw NftSendAssemblyError.substrateNftNotImplemented
        case .ethereum:
            let accountId = accountResponse.isChainAccount ? accountResponse.accountId : nil
            let tag: String = KeystoreTagV2.ethereumSecretKeyTagForMetaId(wallet.metaId, accountId: accountId)

            let secretKey = try keystore.fetchKey(for: tag)

            guard let address = accountResponse.toAddress() else {
                throw ConvenienceError(error: "Cannot fetch address from chain account")
            }

            guard let ws = ChainRegistryFacade.sharedRegistry.getEthereumConnection(for: chain.chainId) else {
                throw ChainRegistryError.connectionUnavailable
            }

            return EthereumNftTransferService(
                ws: ws,
                privateKey: try EthereumPrivateKey(privateKey: secretKey.bytes),
                senderAddress: address
            )
        }
    }
}
