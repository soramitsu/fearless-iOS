import UIKit
import RobinHood
import BigInt
import FearlessUtils
import SoraKeystore

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
    let logger: LoggerProtocol
    let crowdloanOperationFactory: CrowdloanOperationFactoryProtocol
    let connection: JSONRPCEngine?
    let settings: SettingsManagerProtocol

    private(set) var crowdloan: Crowdloan?
    private(set) var crowdloanContribution: CrowdloanContribution?

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
        operationManager: OperationManagerProtocol,
        logger: LoggerProtocol,
        crowdloanOperationFactory: CrowdloanOperationFactoryProtocol,
        connection: JSONRPCEngine?,
        settings: SettingsManagerProtocol
    ) {
        self.paraId = paraId
        self.selectedAccountAddress = selectedAccountAddress
        self.chain = chain
        self.assetId = assetId
        self.crowdloanFundsProvider = crowdloanFundsProvider
        self.settings = settings
        self.runtimeService = runtimeService
        self.feeProxy = feeProxy
        self.extrinsicService = extrinsicService
        self.singleValueProviderFactory = singleValueProviderFactory
        self.logger = logger
        self.crowdloanOperationFactory = crowdloanOperationFactory
        self.connection = connection

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
                self?.crowdloan = crowdloan
                self?.provideContribution()
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

    private func provideContribution() {
        guard let crowdloan = crowdloan else { return }
        guard let connection = connection else {
            presenter.didReceiveCrowdloan(result: .success(crowdloan))
            return
        }

        let contributionOperation: CompoundOperationWrapper<CrowdloanContributionResponse> = crowdloanOperationFactory.fetchContributionOperation(
            connection: connection,
            runtimeService: runtimeService,
            address: selectedAccountAddress,
            trieIndex: crowdloan.fundInfo.trieIndex
        )

        contributionOperation.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                if let crowdloan = self?.crowdloan {
                    self?.presenter.didReceiveCrowdloan(result: .success(crowdloan))
                }

                do {
                    let contributionResponse = try contributionOperation.targetOperation
                        .extractNoCancellableResultData()
                    self?.crowdloanContribution = contributionResponse.contribution
                } catch {
                    self?.logger.error("Cannot receive contributions for crowdloan: \(crowdloan)")
                }
            }
        }

        operationManager.enqueue(operations: contributionOperation.allOperations, in: .transient)
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

    func fetchReferralAccountAddress() {
        if let referralEthereumAccountAddress = settings.referralEthereumAddressForSelectedAccount() {
            presenter.didReceiveReferralEthereumAddress(address: referralEthereumAccountAddress)
        }
    }

    func estimateFee(for amount: BigUInt, bonusService: CrowdloanBonusServiceProtocol?, memo: String?) {
        let contributeCall: RuntimeCall<CrowdloanContributeCall>? = makeContributeCall(amount: amount)
        let memoCall: RuntimeCall<CrowdloanAddMemo>? = makeMemoCall(memo: memo)

        guard contributeCall != nil || memoCall != nil else {
            return
        }

        let builderClosure: ExtrinsicBuilderClosure = { builder in
            var newBuilder = builder

            if let memoCall = memoCall {
                newBuilder = try newBuilder.adding(call: memoCall)
            }

            if let contributeCall = contributeCall {
                newBuilder = try newBuilder.adding(call: contributeCall)
            }

            return try bonusService?.applyOnchainBonusForContribution(
                amount: amount,
                using: newBuilder
            ) ?? newBuilder
        }

        extrinsicService.estimateFee(builderClosure, runningIn: .main) { [weak self] result in
            self?.presenter?.didReceiveFee(result: result)
        }
    }

    private func makeContributeCall(amount: BigUInt) -> RuntimeCall<CrowdloanContributeCall>? {
        callFactory.contribute(to: paraId, amount: amount)
    }

    func makeMemoCall(memo: String?) -> RuntimeCall<CrowdloanAddMemo>? {
        guard let memo = memo, !memo.isEmpty, let memoData = memo.data(using: .utf8) else {
            return nil
        }

        return callFactory.addMemo(to: paraId, memo: memoData)
    }
}

extension CrowdloanContributionInteractor: SingleValueProviderSubscriber, SingleValueSubscriptionHandler {
    func handleBlockNumber(result: Result<BlockNumber?, Error>, chain _: Chain) {
        presenter.didReceiveBlockNumber(result: result)
    }

    func handleAccountInfo(result: Result<AccountInfo?, Error>, address _: AccountAddress) {
        presenter.didReceiveAccountInfo(result: result)

        fetchReferralAccountAddress()
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
