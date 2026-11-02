import UIKit
import RobinHood
import Web3
import SSFModels
import Web3PromiseKit

final class SendInteractor: RuntimeConstantFetching {
    // MARK: - Private properties

    private weak var output: SendInteractorOutput?

    private let accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol
    private let operationManager: OperationManagerProtocol
    private let scamInfoFetching: ScamInfoFetching
    private let chainAssetFetching: ChainAssetFetchingProtocol
    private let addressChainDefiner: AddressChainDefiner
    private var equilibriumTotalBalanceService: EquilibriumTotalBalanceServiceProtocol?
    private let runtimeItemRepository: AsyncAnyRepository<RuntimeMetadataItem>
    private let accountInfoRemoteService: AccountInfoRemoteService

    let dependencyContainer: SendDepencyContainer

    private let requestScope = SendRequestScope()
    private let feeScope = SendRequestScope()
    private let scamScope = SendRequestScope()
    private let prepareDependencies: (ChainAsset) async throws -> SendDependencies
    private var dependenciesRequest: UUID?
    private var feeListener: SendScopedFeeListener?
    private var accountInfoListener: SendScopedAccountInfoListener?
    private var dependencies: SendDependencies?

    init(
        accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol,
        operationManager: OperationManagerProtocol,
        scamInfoFetching: ScamInfoFetching,
        chainAssetFetching: ChainAssetFetchingProtocol,
        dependencyContainer: SendDepencyContainer,
        addressChainDefiner: AddressChainDefiner,
        runtimeItemRepository: AsyncAnyRepository<RuntimeMetadataItem>,
        accountInfoRemoteService: AccountInfoRemoteService,
        prepareDependencies: ((ChainAsset) async throws -> SendDependencies)? = nil
    ) {
        self.accountInfoSubscriptionAdapter = accountInfoSubscriptionAdapter
        self.operationManager = operationManager
        self.scamInfoFetching = scamInfoFetching
        self.chainAssetFetching = chainAssetFetching
        self.dependencyContainer = dependencyContainer
        self.addressChainDefiner = addressChainDefiner
        self.runtimeItemRepository = runtimeItemRepository
        self.accountInfoRemoteService = accountInfoRemoteService
        self.prepareDependencies = prepareDependencies ?? { try await dependencyContainer.prepareDepencies(chainAsset: $0) }
    }

    // MARK: - Private methods

    private func subscribeToAccountInfo(for chainAsset: ChainAsset, utilityAsset: ChainAsset? = nil) {
        guard let dependencies = dependencies, let request = dependenciesRequest, requestScope.isCurrent(request) else {
            return
        }

        if UniversalWalletRegistry.readsBalanceRemotely(chainAsset.chain.chainId) {
            Task { [weak self] in
                guard let self else {
                    return
                }

                do {
                    let accountInfo = try await accountInfoRemoteService.fetchAccountInfo(
                        for: chainAsset,
                        wallet: dependencies.wallet
                    )
                    await MainActor.run {
                        guard self.requestScope.isCurrent(request) else { return }
                        self.output?.didReceiveAccountInfo(
                            result: .success(accountInfo),
                            for: chainAsset
                        )
                    }
                } catch {
                    await MainActor.run {
                        guard self.requestScope.isCurrent(request) else { return }
                        self.output?.didReceiveAccountInfo(
                            result: .failure(error),
                            for: chainAsset
                        )
                    }
                }
            }
            return
        }

        if let accountId = dependencies.wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId {
            dependencies.accountInfoFetching.fetch(for: chainAsset, accountId: accountId) { [weak self] chainAsset, accountInfo in

                DispatchQueue.main.async {
                    guard let self, self.requestScope.isCurrent(request) else { return }
                    self.output?.didReceiveAccountInfo(result: .success(accountInfo), for: chainAsset)
                    let chainAssets: [ChainAsset] = [chainAsset, utilityAsset].compactMap { $0 }
                    self.accountInfoSubscriptionAdapter.subscribe(
                        chainsAssets: chainAssets,
                        handler: self.accountInfoListener
                    )
                }
            }
        }
    }

    private func updateDependencies(for chainAsset: ChainAsset) {
        let request = requestScope.begin()
        feeScope.begin()
        scamScope.begin()
        Task { @MainActor in
            guard requestScope.isCurrent(request) else { return }
            accountInfoSubscriptionAdapter.reset()
            accountInfoListener = nil
            self.dependencies = nil
            dependenciesRequest = nil
            feeListener = nil
            let dependencies: SendDependencies
            do {
                dependencies = try await prepareDependencies(chainAsset)
            } catch {
                // Routing refusals (paused or unavailable sends, missing accounts) and connection
                // failures must reach the screen; otherwise Send waits for a fee that never comes.
                // The previous network's services must not quote fees for this one.
                guard requestScope.isCurrent(request) else { return }
                self.dependencies = nil
                output?.didReceiveDependenciesError(error, for: chainAsset)
                return
            }
            guard requestScope.isCurrent(request) else { return }
            self.dependencies = dependencies
            dependenciesRequest = request
            accountInfoSubscriptionAdapter.update(wallet: dependencies.wallet)
            accountInfoListener = SendScopedAccountInfoListener(wallet: dependencies.wallet, scope: requestScope, request: request) { [weak self] result, asset in
                self?.output?.didReceiveAccountInfo(result: result, for: asset)
            }

            if UniversalWalletRegistry.readsBalanceRemotely(chainAsset.chain.chainId) {
                output?.didReceiveAssetAccountInfo(assetAccountInfo: nil)
                subscribeToAccountInfo(for: chainAsset)
                // A Solana token transfer pays its fee in SOL, so Send needs that balance too.
                if !chainAsset.isUtility, let utilityAsset = getFeePaymentChainAsset(for: chainAsset) {
                    subscribeToAccountInfo(for: utilityAsset)
                }
                output?.didReceiveMinimumBalance(result: .success(.zero))
                output?.didReceiveDependencies(for: chainAsset)
                return
            }

            getTokensStatus(for: chainAsset)

            if !chainAsset.isUtility,
               let utilityAsset = getFeePaymentChainAsset(for: chainAsset) {
                subscribeToAccountInfo(for: chainAsset, utilityAsset: utilityAsset)
                provideConstants(for: utilityAsset)
            } else {
                subscribeToAccountInfo(for: chainAsset)
                provideConstants(for: chainAsset)
            }

            output?.didReceiveDependencies(for: chainAsset)
        }
    }

    private func getTokensStatus(for chainAsset: ChainAsset) {
        guard let dependencies, let request = dependenciesRequest, requestScope.isCurrent(request) else { return }
        guard
            let currencyId = chainAsset.currencyId,
            let accountId = dependencies.wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId
        else {
            DispatchQueue.main.async { [weak self] in
                guard let self, self.requestScope.isCurrent(request) else { return }
                self.output?.didReceiveAssetAccountInfo(assetAccountInfo: nil)
            }
            return
        }

        Task {
            do {
                let storageRequest = AssetsAccountRequest(accountId: accountId, currencyId: currencyId)
                let assetAccountInfo: AssetAccountInfo? = try await dependencies.storageRequestPerformer?.performSingle(storageRequest)

                await MainActor.run {
                    guard requestScope.isCurrent(request) else { return }
                    output?.didReceiveAssetAccountInfo(assetAccountInfo: assetAccountInfo)
                }
            } catch {
                await MainActor.run {
                    guard requestScope.isCurrent(request) else { return }
                    output?.didReceiveAssetAccountInfoError(error: error)
                }
            }
        }
    }
}

extension SendInteractor: SendInteractorInput {
    func setup(with output: SendInteractorOutput) {
        self.output = output
    }

    func updateSubscriptions(for chainAsset: ChainAsset) {
        updateDependencies(for: chainAsset)
    }

    func defineAvailableChains(
        for chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        completionBlock: @escaping ([ChainModel]?) -> Void
    ) {
        chainAssetFetching.fetch(
            shouldUseCache: true,
            filters: [.enabled(wallet: wallet)],
            sortDescriptors: []
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case let .success(chainAssets):
                    let members = SendNetworkSelection.members(for: chainAsset, among: chainAssets).filter {
                        wallet.fetch(for: $0.chain.accountRequest()) != nil &&
                            AssetVisibilityPreferenceStore.preference(walletId: wallet.metaId, assetKey: $0.assetKey) != .hidden
                    }
                    var seen = Set<ChainModel.Id>()
                    let chains = members.map(\.chain).filter { seen.insert($0.chainId).inserted }
                    completionBlock(chains)
                default:
                    completionBlock(nil)
                }
            }
        }
    }

    func estimateFee(for amount: BigUInt, tip: BigUInt?, for address: String?, chainAsset: ChainAsset) {
        guard let dependencies = dependencies, let request = dependenciesRequest, requestScope.isCurrent(request) else {
            return
        }

        let senderAddress = UniversalWalletAccountAddressResolver.address(for: chainAsset.chain, wallet: dependencies.wallet) ??
            dependencies.wallet.fetch(for: chainAsset.chain.accountRequest())?.toAddress()

        guard let senderAddress else {
            return
        }

        let address = address ?? senderAddress
        // New SSF ChainOptions no longer exposes .checkAppId; default to nil appId
        let appId: BigUInt? = nil
        let transfer = Transfer(
            chainAsset: chainAsset,
            amount: amount,
            receiver: address,
            tip: tip,
            appId: appId
        )

        guard dependencies.chainAsset.assetKey == chainAsset.assetKey else { return }
        let listener = SendScopedFeeListener(scope: feeScope, request: feeScope.begin()) { [weak self] result in
            guard let self, self.requestScope.isCurrent(request) else { return }
            self.output?.didReceiveFee(result: result)
        }
        feeListener = listener
        dependencies.transferService.subscribeForFee(transfer: transfer, listener: listener)
    }

    func invalidateScamInfo() {
        scamScope.begin()
    }

    func fetchScamInfo(for address: String, chain: ChainModel) {
        let request = scamScope.begin()
        Task { @MainActor in
            guard scamScope.isCurrent(request) else { return }
            let scamInfo = try? await scamInfoFetching.fetch(address: address, chain: chain)
            guard scamScope.isCurrent(request) else { return }
            output?.didReceive(scamInfo: scamInfo)
        }
    }

    func getFeePaymentChainAsset(for chainAsset: ChainAsset?) -> ChainAsset? {
        guard let chainAsset = chainAsset else { return nil }
        if let utilityAsset = chainAsset.chain.utilityChainAssets().first {
            return utilityAsset
        }
        return chainAsset
    }

    func getPossibleChains(for address: String) async -> [ChainModel]? {
        await addressChainDefiner.getPossibleChains(for: address)
    }

    func validate(address: String?, for chain: ChainModel) -> AddressValidationResult {
        addressChainDefiner.validate(address: address, for: chain)
    }

    func calculateEquilibriumBalance(chainAsset: ChainAsset, amount: Decimal) {
        if chainAsset.chain.isEquilibrium {
            let totalBalanceAfterTransfer = equilibriumTotalBalanceService?
                .totalBalanceAfterTransfer(chainAsset: chainAsset, amount: amount) ?? .zero
            output?.didReceive(eqTotalBalance: totalBalanceAfterTransfer)
        }
    }

    func didReceive(xorlessTransfer: XorlessTransfer) {
        guard let dependencies = dependencies, let request = dependenciesRequest, requestScope.isCurrent(request) else {
            return
        }

        let feeRequest = feeScope.begin()
        Task {
            do {
                let fee = try await dependencies.transferService.estimateFee(for: xorlessTransfer)
                await MainActor.run(body: {
                    guard requestScope.isCurrent(request), feeScope.isCurrent(feeRequest) else { return }
                    output?.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: fee)))
                })
            } catch {
                await MainActor.run(body: {
                    guard requestScope.isCurrent(request), feeScope.isCurrent(feeRequest) else { return }
                    output?.didReceiveFee(result: .failure(error))
                })
            }
        }
    }

    func convert(chainAsset: ChainAsset, toChainAsset: ChainAsset, amount: BigUInt) async throws -> SwapValues? {
        guard let request = dependenciesRequest, requestScope.isCurrent(request), let polkaswapService = dependencies?.polkaswapService else {
            throw ConvenienceError(error: "Dependencies not ready")
        }
        let quote = try await polkaswapService.fetchQuotes(amount: amount, fromChainAsset: chainAsset, toChainAsset: toChainAsset)
        guard requestScope.isCurrent(request) else { throw CancellationError() }
        return quote
    }

    func provideConstants(for chainAsset: ChainAsset) {
        guard let dependencies = dependencies, let request = dependenciesRequest, requestScope.isCurrent(request) else {
            return
        }

        guard let runtimeService = dependencies.runtimeService else {
            return
        }

        dependencies.existentialDepositService.fetchExistentialDeposit(
            chainAsset: chainAsset
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self, self.requestScope.isCurrent(request) else { return }
                self.output?.didReceiveMinimumBalance(result: result)
            }
        }

        if chainAsset.chain.isTipRequired {
            fetchConstant(
                for: .defaultTip,
                runtimeCodingService: runtimeService,
                operationManager: operationManager
            ) { [weak self] (result: Swift.Result<BigUInt, Error>) in
                DispatchQueue.main.async {
                    guard let self, self.requestScope.isCurrent(request) else { return }
                    self.output?.didReceiveTip(result: result)
                }
            }
        }
        if chainAsset.chain.isEquilibrium {
            equilibriumTotalBalanceService = dependencies.equilibruimTotalBalanceService
        }
    }
}
