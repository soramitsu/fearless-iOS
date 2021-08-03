import UIKit
import RobinHood
import BigInt

class CrowdloanContributionInteractor: CrowdloanContributionInteractorInputProtocol, RuntimeConstantFetching {
    weak var presenter: CrowdloanContributionInteractorOutputProtocol!

    let paraId: ParaId
    let selectedAccountAddress: AccountAddress
    let chain: Chain
    let assetId: WalletAssetId
    let runtimeService: RuntimeCodingServiceProtocol
    let feeProxy: ExtrinsicFeeProxyProtocol
    let extrinsicService: ExtrinsicServiceProtocol
    let singleValueProviderFactory: SingleValueProviderFactoryProtocol
    let displayInfoProvider: AnySingleValueProvider<CrowdloanDisplayInfoList>
    let crowdloanFundsProvider: AnyDataProvider<DecodedCrowdloanFunds>
    let operationManager: OperationManagerProtocol

    private var blockNumberProvider: AnyDataProvider<DecodedBlockNumber>?
    private var balanceProvider: AnyDataProvider<DecodedAccountInfo>?
    private var priceProvider: AnySingleValueProvider<PriceData>?

    private(set) lazy var callFactory = SubstrateCallFactory()

    init(
        paraId: ParaId,
        selectedAccountAddress: AccountAddress,
        chain: Chain,
        assetId: WalletAssetId,
        runtimeService: RuntimeCodingServiceProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        crowdloanFundsProvider: AnyDataProvider<DecodedCrowdloanFunds>,
        singleValueProviderFactory: SingleValueProviderFactoryProtocol,
        operationManager: OperationManagerProtocol
    ) {
        self.paraId = paraId
        self.selectedAccountAddress = selectedAccountAddress
        self.chain = chain
        self.assetId = assetId
        self.crowdloanFundsProvider = crowdloanFundsProvider

        self.runtimeService = runtimeService
        self.feeProxy = feeProxy
        self.extrinsicService = extrinsicService
        self.singleValueProviderFactory = singleValueProviderFactory

        displayInfoProvider = singleValueProviderFactory.getJson(
            for: chain.crowdloanDisplayInfoURL()
        )

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

        fetchConstant(
            for: .existentialDeposit,
            runtimeCodingService: runtimeService,
            operationManager: operationManager
        ) { [weak self] (result: Result<BigUInt, Error>) in
            self?.presenter.didReceiveMinimumBalance(result: result)
        }

        fetchConstant(
            for: .minimumContribution,
            runtimeCodingService: runtimeService,
            operationManager: operationManager
        ) { [weak self] (result: Result<BigUInt, Error>) in
            self?.presenter.didReceiveMinimumContribution(result: result)
        }
    }

    private func subscribeToDisplayInfo() {
        let updateClosure: ([DataProviderChange<CrowdloanDisplayInfoList>]) -> Void = { [weak self] changes in
            if let result = changes.reduceToLastChange(), let paraId = self?.paraId {
                let displayInfoDict = result.toMap()
                let displayInfo = displayInfoDict[paraId]
                self?.presenter.didReceiveDisplayInfo(result: .success(displayInfo))
            }
        }

        let failureClosure: (Error) -> Void = { [weak self] error in
            self?.presenter.didReceiveDisplayInfo(result: .failure(error))
        }

        let options = DataProviderObserverOptions(alwaysNotifyOnRefresh: true, waitsInProgressSyncOnAdd: false)

        displayInfoProvider.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )
    }

    private func subscribeToCrowdloanFunds() {
        let updateClosure: ([DataProviderChange<DecodedCrowdloanFunds>]) -> Void = { [weak self] changes in
            if
                let result = changes.reduceToLastChange(),
                let crowdloanFunds = result.item,
                let paraId = self?.paraId {
                let crowdloan = Crowdloan(paraId: paraId, fundInfo: crowdloanFunds)
                self?.presenter.didReceiveCrowdloan(result: .success(crowdloan))
            }
        }

        let failureClosure: (Error) -> Void = { [weak self] error in
            self?.presenter.didReceiveDisplayInfo(result: .failure(error))
        }

        let options = DataProviderObserverOptions(alwaysNotifyOnRefresh: false, waitsInProgressSyncOnAdd: false)

        crowdloanFundsProvider.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )
    }

    func setup() {
        feeProxy.delegate = self

        blockNumberProvider = subscribeToBlockNumber(for: chain, runtimeService: runtimeService)

        balanceProvider = subscribeToAccountInfoProvider(
            for: selectedAccountAddress,
            runtimeService: runtimeService
        )

        priceProvider = subscribeToPriceProvider(for: assetId)

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

extension CrowdloanContributionInteractor: SingleValueProviderSubscriber, SingleValueSubscriptionHandler {
    func handleBlockNumber(result: Result<BlockNumber?, Error>, chain _: Chain) {
        presenter.didReceiveBlockNumber(result: result)
    }

    func handleAccountInfo(result: Result<AccountInfo?, Error>, address _: AccountAddress) {
        presenter.didReceiveAccountInfo(result: result)
    }

    func handlePrice(result: Result<PriceData?, Error>, for _: WalletAssetId) {
        presenter.didReceivePriceData(result: result)
    }
}

extension CrowdloanContributionInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>, for _: ExtrinsicFeeId) {
        presenter.didReceiveFee(result: result)
    }
}
