import UIKit
import SoraFoundation
import SSFModels
import SoraKeystore
import Web3
import RobinHood
import SSFUtils

enum NftSendAssemblyError: Error {
    case substrateNftNotImplemented
}

enum NftSendAssembly {
    static func configureModule(nft: NFT, wallet: MetaAccountModel) -> NftSendModuleCreationResult? {
        do {
            let localizationManager = LocalizationManager.shared

            let repositoryFacade = SubstrateDataStorageFacade.shared
            let mapper: CodableCoreDataMapper<ScamInfo, CDScamInfo> =
                CodableCoreDataMapper(entityIdentifierFieldName: #keyPath(CDScamInfo.address))
            let scamRepository: CoreDataRepository<ScamInfo, CDScamInfo> =
                repositoryFacade.createRepository(
                    filter: nil,
                    sortDescriptors: [],
                    mapper: AnyCoreDataMapper(mapper)
                )
            let scamServiceOperationFactory = ScamServiceOperationFactory(
                repository: AnyDataProviderRepository(scamRepository)
            )
            let operationManager = OperationManagerFacade.sharedManager

            let transferService = try createTransferService(for: nft.chain, wallet: wallet)
            let chainRepository = ChainRepositoryFactory().createRepository(
                sortDescriptors: [NSSortDescriptor.chainsByAddressPrefix]
            )
            let addressChainDefiner = AddressChainDefiner(
                operationManager: operationManager,
                chainModelRepository: AnyDataProviderRepository(chainRepository),
                wallet: wallet
            )
            let interactor = NftSendInteractor(
                transferService: transferService,
                operationManager: OperationManagerFacade.sharedManager,
                scamServiceOperationFactory: scamServiceOperationFactory,
                addressChainDefiner: addressChainDefiner
            )
            let router = NftSendRouter()

            let presenter = NftSendPresenter(
                interactor: interactor,
                router: router,
                localizationManager: localizationManager,
                nft: nft,
                wallet: wallet,
                logger: Logger.shared, viewModelFactory:
                SendViewModelFactory(iconGenerator: UniversalIconGenerator())
            )

            let view = NftSendViewController(
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
