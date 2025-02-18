import UIKit
import SSFModels
import SSFTransferService
import SSFStorageQueryKit
import BigInt
import RobinHood

protocol TransferInteractorOutput: AnyObject {}

struct TransferDepsContainer {
    let wallet: MetaAccountModel

    init(wallet: MetaAccountModel) {
        self.wallet = wallet
    }

    lazy var chainRegistry: ChainRegistryProtocol = {
        ServiceAssembly.shared.chainRegistry
    }()

    lazy var operationManager: OperationManagerProtocol = {
        ServiceAssembly.shared.operationManager
    }()

    lazy var existentialDepositService: ExistentialDepositServiceProtocol = {
        ServiceAssembly.shared.existentialDepositService()
    }()

    lazy var transferService: TransferService = {
        ServiceAssembly.shared.transferService(for: wallet)
    }()

    lazy var polkaswapService: PolkaswapService = {
        ServiceAssembly.shared.polkaswapService()
    }()

    lazy var storageRequestPerformer: SSFStorageQueryKit.StorageRequestPerformer = {
        SSFStorageQueryKit.StorageRequestPerformerDefault(
            chainRegistry: ServiceAssembly.shared.chainRegistry
        )
    }()

    lazy var accountInfoRemoteService: AccountInfoRemoteService = {
        ServiceAssembly.shared.accountInfoRemoteServiceDefault()
    }()

    lazy var addressChainDefiner: AddressChainDefiner = {
        ServiceAssembly.shared.addressChainDefiner(wallet: wallet)
    }()
    
    lazy var accountInfoFetchingProvider: AccountInfoFetching = {
        let substrateRepositoryFactory = SubstrateRepositoryFactory(
            storageFacade: UserDataStorageFacade.shared
        )

        let accountRepositoryFactory = AccountRepositoryFactory(storageFacade: UserDataStorageFacade.shared)
        let accountRepository = accountRepositoryFactory.createMetaAccountRepository(for: nil, sortDescriptors: [])
        let accountInfoRepository = substrateRepositoryFactory.createAccountInfoStorageItemRepository()
        let chainRegistry = ChainRegistryFacade.sharedRegistry
        let accountInfoFetching = AccountInfoFetching(
            accountInfoRepository: accountInfoRepository,
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            operationQueue: OperationQueue()
        )
        return accountInfoFetching
    }()
}

actor TransferInteractor: RuntimeConstantFetching {
    // MARK: - Private properties

    private weak var output: TransferInteractorOutput?

    private var deps: TransferDepsContainer
    private let chainAssetFetching: ChainAssetFetchingProtocol
    private let scamRepository: AsyncAnyRepository<ScamInfo>

    init(
        deps: TransferDepsContainer,
        chainAssetFetching: ChainAssetFetchingProtocol,
        scamRepository: AsyncAnyRepository<ScamInfo>
    ) {
        self.deps = deps
        self.chainAssetFetching = chainAssetFetching
        self.scamRepository = scamRepository
    }

    // MARK: - Private methods

    private func getChainAssets(for chainAsset: ChainAsset) -> [ChainAsset] {
        [chainAsset, chainAsset.chain.utilityChainAssets().first]
            .compactMap { $0 }
            .uniq(predicate: { $0.chainAssetId })
    }
}

// MARK: - TransferInteractorInput

extension TransferInteractor: TransferInteractorInput {
    func getScamInfo(for address: String) async throws -> ScamInfo? {
        try await scamRepository.fetch(by: address, options: RepositoryFetchOptions())
    }

    func setup(with output: TransferInteractorOutput) async {
        self.output = output
    }

    func validate(address: String?, for chain: SSFModels.ChainModel) -> AddressValidationResult {
        deps.addressChainDefiner.validate(address: address, for: chain)
    }

    func getPossibleChains(for address: String) async -> [ChainModel] {
        await deps.addressChainDefiner.getPossibleChains(for: address).or([])
    }

    func fetchTokenStatus(for chainAsset: ChainAsset) async throws -> AssetAccountInfo? {
        guard
            let currencyId = chainAsset.currencyId,
            let accountId = deps.wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId
        else {
            return nil
        }

        let accountIdVariant = try AccountIdVariant.build(raw: accountId, chain: chainAsset.chain)
        let request = AssetsAccountRequest1(accountId: accountIdVariant, currencyId: currencyId)
        let assetAccountInfo: AssetAccountInfo? = try await deps
            .storageRequestPerformer
            .performSingle(request, chain: chainAsset.chain)

        return assetAccountInfo
    }

    func fetchAccountInfos(for chainAsset: ChainAsset) async throws -> [ChainAssetKey: AccountInfo?] {
        let chainAssets = getChainAssets(for: chainAsset)
        return try await deps.accountInfoFetchingProvider.fetchByUniqKey(for: chainAssets, wallet: deps.wallet)
       
    }

    func fetchExistentialDeposit(for chainAsset: ChainAsset) async throws -> BigUInt {
        try await deps
            .existentialDepositService
            .fetchExistentialDeposit(chainAsset: chainAsset)
    }

    func fetchTip(for chainAsset: ChainAsset) async throws -> BigUInt {
        guard let runtimeCodingService = deps
            .chainRegistry
            .getRuntimeProvider(for: chainAsset.chain.chainId)
        else {
            throw RuntimeProviderError.providerUnavailable
        }

        let tip: BigUInt = try await fetchConstant(
            for: .defaultTip,
            runtimeCodingService: runtimeCodingService,
            operationManager: deps.operationManager
        )

        return tip
    }

    func convert(
        chainAsset: ChainAsset,
        toChainAsset: ChainAsset,
        amount: BigUInt
    ) async throws -> SwapValues? {
        try await deps
            .polkaswapService
            .fetchQuotes(
                amount: amount,
                fromChainAsset: chainAsset,
                toChainAsset: toChainAsset
            )
    }

    func defineAvailableChains(
        for asset: AssetModel,
        wallet: MetaAccountModel
    ) async throws -> [ChainModel]? {
        let chainAssets = try await chainAssetFetching.fetchAwait(
            shouldUseCache: true,
            filters: [.enabled(wallet: wallet) ],
            sortDescriptors: []
        )
        let chains = chainAssets.filter { $0.asset.symbolUppercased == asset.symbolUppercased }.map { $0.chain }
        return chains
    }

    func estimateFee(
        transfer: TransferType,
        chainAsset: ChainAsset
    ) async -> AsyncThrowingStream<BigUInt, Error> {
        await deps.transferService.estimateFee(
            transfer,
            for: chainAsset
        )
    }

    func submit(
        transfer: TransferType,
        chainAsset: ChainAsset
    ) async throws -> String? {
        try await deps.transferService.submit(
            transfer,
            for: chainAsset
        )
    }
}

struct AssetsAccountRequest1: SSFStorageQueryKit.StorageRequest {
    let accountId: AccountIdVariant
    let currencyId: CurrencyId

    var parametersType: SSFStorageQueryKit.StorageRequestParametersType {
        switch accountId {
        case let .accountId(accountId):
            return .nMap(params: [
                [NMapKeyParam(value: currencyId)],
                [NMapKeyParam(value: accountId)]
            ])
        case let .address(address):
            return .nMap(params: [
                [NMapKeyParam(value: currencyId)],
                [NMapKeyParam(value: address)]
            ])
        }
    }

    var storagePath: any StorageCodingPathProtocol {
        StorageCodingPath.assetsAccount
    }
}
