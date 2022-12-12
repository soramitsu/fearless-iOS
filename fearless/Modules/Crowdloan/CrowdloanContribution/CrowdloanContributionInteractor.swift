import UIKit
import RobinHood
import BigInt

class CrowdloanContributionInteractor: CrowdloanContributionInteractorInputProtocol, RuntimeConstantFetching {
    weak var presenter: CrowdloanContributionInteractorOutputProtocol!

    internal let crowdloanLocalSubscriptionFactory: CrowdloanLocalSubscriptionFactoryProtocol
    internal let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    internal let jsonLocalSubscriptionFactory: JsonDataProviderFactoryProtocol
    let paraId: ParaId
    let selectedMetaAccount: MetaAccountModel
    let extrinsicService: ExtrinsicServiceProtocol
    let chainAsset: ChainAsset
    private let runtimeService: RuntimeCodingServiceProtocol
    private let feeProxy: ExtrinsicFeeProxyProtocol
    private let accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol
    private let operationManager: OperationManagerProtocol
    private let existentialDepositService: ExistentialDepositServiceProtocol

    private var blockNumberProvider: AnyDataProvider<DecodedBlockNumber>?
    private var balanceProvider: AnyDataProvider<DecodedAccountInfo>?
    private var ormlBalanceProvider: AnyDataProvider<DecodedOrmlAccountInfo>?
    private var priceProvider: AnySingleValueProvider<PriceData>?
    private var crowdloanProvider: AnyDataProvider<DecodedCrowdloanFunds>?
    private var displayInfoProvider: AnySingleValueProvider<CrowdloanDisplayInfoList>?

    private(set) lazy var callFactory = SubstrateCallFactory()

    init(
        paraId: ParaId,
        selectedMetaAccount: MetaAccountModel,
        chainAsset: ChainAsset,
        runtimeService: RuntimeCodingServiceProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        crowdloanLocalSubscriptionFactory: CrowdloanLocalSubscriptionFactoryProtocol,
        accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        jsonLocalSubscriptionFactory: JsonDataProviderFactoryProtocol,
        operationManager: OperationManagerProtocol,
        existentialDepositService: ExistentialDepositServiceProtocol
    ) {
        self.paraId = paraId
        self.selectedMetaAccount = selectedMetaAccount
        self.chainAsset = chainAsset
        self.runtimeService = runtimeService
        self.feeProxy = feeProxy
        self.extrinsicService = extrinsicService
        self.crowdloanLocalSubscriptionFactory = crowdloanLocalSubscriptionFactory
        self.accountInfoSubscriptionAdapter = accountInfoSubscriptionAdapter
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.jsonLocalSubscriptionFactory = jsonLocalSubscriptionFactory
        self.existentialDepositService = existentialDepositService
        self.operationManager = operationManager
    }

    private func provideConstants() {
        fetchConstant(
            for: .babeBlockTime,
            runtimeCodingService: runtimeService,
            operationManager: operationManager
        ) { [weak self] (result: Result<BlockTime, Error>) in
            self?.presenter.didReceiveBlockDuration(result: result)
        }

        fetchConstant(
            for: .paraLeasingPeriod,
            runtimeCodingService: runtimeService,
            operationManager: operationManager
        ) { [weak self] (result: Result<LeasingPeriod, Error>) in
            self?.presenter.didReceiveLeasingPeriod(result: result)
        }

        existentialDepositService.fetchExistentialDeposit(
            chainAsset: chainAsset
        ) { [weak self] result in
            self?.presenter?.didReceiveMinimumBalance(result: result)
        }

        fetchConstant(
            for: .minimumContribution,
            runtimeCodingService: runtimeService,
            operationManager: operationManager
        ) { [weak self] (result: Result<BigUInt, Error>) in
            self?.presenter.didReceiveMinimumContribution(result: result)
        }

        fetchConstant(
            for: .leaseOffset,
            runtimeCodingService: runtimeService,
            operationManager: operationManager
        ) { [weak self] (result: Result<LeasingOffset, Error>) in
            self?.presenter.didReceiveLeasingOffset(result: result)
        }
    }

    private func subscribeToDisplayInfo() {
        if let displayInfoUrl = chainAsset.chain.externalApi?.crowdloans?.url {
            displayInfoProvider = subscribeToCrowdloanDisplayInfo(
                for: displayInfoUrl,
                chainId: chainAsset.chain.chainId
            )
        } else {
            presenter.didReceiveDisplayInfo(result: .success(nil))
        }
    }

    private func subscribeToCrowdloanFunds() {
        crowdloanProvider = subscribeToCrowdloanFunds(for: paraId, chainId: chainAsset.chain.chainId)
    }

    private func subscribeToAccountInfo() {
        guard let accountId = selectedMetaAccount.fetch(for: chainAsset.chain.accountRequest())?.accountId else {
            presenter.didReceiveAccountInfo(result: .failure(ChainAccountFetchingError.accountNotExists))
            return
        }

        accountInfoSubscriptionAdapter.subscribe(chainAsset: chainAsset, accountId: accountId, handler: self)
    }

    private func subscribeToPrice() {
        if let priceId = chainAsset.asset.priceId {
            priceProvider = subscribeToPrice(for: priceId)
        } else {
            presenter.didReceivePriceData(result: .success(nil))
        }
    }

    func setup() {
        feeProxy.delegate = self

        blockNumberProvider = subscribeToBlockNumber(for: chainAsset.chain.chainId)

        subscribeToPrice()
        subscribeToAccountInfo()
        subscribeToDisplayInfo()
        subscribeToCrowdloanFunds()

        provideConstants()
    }

    func estimateFee(for amount: BigUInt, bonusService: CrowdloanBonusServiceProtocol?) {
        let call = callFactory.contribute(to: paraId, amount: amount)

        let identifier = String(amount)

        feeProxy.estimateFee(using: extrinsicService, reuseIdentifier: identifier) { builder in
            let nextBuilder = try builder.adding(call: call)
            return try bonusService?.applyOnchainBonusForContribution(
                amount: amount,
                using: nextBuilder
            ) ?? nextBuilder
        }
    }
}

extension CrowdloanContributionInteractor: CrowdloanLocalStorageSubscriber,
    CrowdloanLocalSubscriptionHandler {
    func handleBlockNumber(result: Result<BlockNumber?, Error>, chainId _: ChainModel.Id) {
        presenter.didReceiveBlockNumber(result: result)
    }

    func handleCrowdloanFunds(
        result: Result<CrowdloanFunds?, Error>,
        for paraId: ParaId,
        chainId _: ChainModel.Id
    ) {
        do {
            if let crowdloanFunds = try result.get() {
                let crowdloan = Crowdloan(paraId: paraId, fundInfo: crowdloanFunds)
                presenter.didReceiveCrowdloan(result: .success(crowdloan))
            }
        } catch {
            presenter.didReceiveCrowdloan(result: .failure(error))
        }
    }
}

extension CrowdloanContributionInteractor: AccountInfoSubscriptionAdapterHandler {
    func handleAccountInfo(
        result: Result<AccountInfo?, Error>,
        accountId _: AccountId,
        chainAsset _: ChainAsset
    ) {
        presenter.didReceiveAccountInfo(result: result)
    }
}

extension CrowdloanContributionInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        presenter.didReceivePriceData(result: result)
    }
}

extension CrowdloanContributionInteractor: JsonLocalStorageSubscriber, JsonLocalSubscriptionHandler {
    func handleCrowdloanDisplayInfo(
        result: Result<CrowdloanDisplayInfoList?, Error>,
        url _: URL,
        chainId _: ChainModel.Id
    ) {
        do {
            if let result = try result.get() {
                let displayInfoDict = result.toMap()
                let displayInfo = displayInfoDict[paraId]
                presenter.didReceiveDisplayInfo(result: .success(displayInfo))
            } else {
                presenter.didReceiveDisplayInfo(result: .success(nil))
            }
        } catch {
            presenter.didReceiveDisplayInfo(result: .failure(error))
        }
    }
}

extension CrowdloanContributionInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>, for _: ExtrinsicFeeId) {
        presenter.didReceiveFee(result: result)
    }
}
