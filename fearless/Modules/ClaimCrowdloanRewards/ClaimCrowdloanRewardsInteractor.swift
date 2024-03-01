import UIKit
import SSFUtils
import SSFModels
import RobinHood
import SSFSigner

final class ClaimCrowdloanRewardsInteractor {
    // MARK: - Private properties

    private weak var output: ClaimCrowdloanRewardsInteractorOutput?

    private let callFactory: SubstrateCallFactoryProtocol
    private let wallet: MetaAccountModel
    private let chainAsset: ChainAsset
    private let crowdloanOperationFactory: CrowdloanOperationFactoryProtocol
    private let operationQueue: OperationQueue
    private let feeProxy: ExtrinsicFeeProxyProtocol
    private let extrinsicService: ExtrinsicServiceProtocol
    private let signer: SigningWrapperProtocol
    private let priceLocalSubscriber: PriceLocalStorageSubscriber
    private var priceProvider: AnySingleValueProvider<[PriceData]>?
    private let networkInfoFetcher: NetworkInfoFetching
    private let chainRegistry: ChainRegistryProtocol
    private let storageRequestPerformer: StorageRequestPerformer
    private let accountInfoFetcher: AccountInfoFetchingProtocol

    init(
        callFactory: SubstrateCallFactoryProtocol,
        wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        crowdloanOperationFactory: CrowdloanOperationFactoryProtocol,
        operationQueue: OperationQueue,
        feeProxy: ExtrinsicFeeProxyProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        signer: SigningWrapperProtocol,
        priceLocalSubscriber: PriceLocalStorageSubscriber,
        networkInfoFetcher: NetworkInfoFetching,
        chainRegistry: ChainRegistryProtocol,
        storageRequestPerformer: StorageRequestPerformer,
        accountInfoFetcher: AccountInfoFetchingProtocol
    ) {
        self.callFactory = callFactory
        self.wallet = wallet
        self.chainAsset = chainAsset
        self.crowdloanOperationFactory = crowdloanOperationFactory
        self.operationQueue = operationQueue
        self.feeProxy = feeProxy
        self.extrinsicService = extrinsicService
        self.signer = signer
        self.priceLocalSubscriber = priceLocalSubscriber
        self.networkInfoFetcher = networkInfoFetcher
        self.chainRegistry = chainRegistry
        self.storageRequestPerformer = storageRequestPerformer
        self.accountInfoFetcher = accountInfoFetcher

        self.feeProxy.delegate = self
    }

    private func fetchTokenLocks() {
        guard
            let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId,
            let currencyId = chainAsset.currencyId
        else {
            output?.didReceiveBalanceLocksError(ChainAccountFetchingError.accountNotExists)
            return
        }

        Task {
            do {
                let tokensLocksRequest = TokensLocksRequestBuilder().buildRequest(for: chainAsset, accountId: accountId, currencyId: currencyId)
                let locks: TokenLocks? = try await storageRequestPerformer.performRequest(tokensLocksRequest)

                await MainActor.run {
                    output?.didReceiveTokenLocks(locks)
                }
            } catch {
                await MainActor.run {
                    output?.didReceiveTokenLocksError(error)
                }
            }
        }
    }

    private func fetchBalanceLocks() {
        guard let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId else {
            output?.didReceiveBalanceLocksError(ChainAccountFetchingError.accountNotExists)
            return
        }

        Task {
            do {
                let balancesLocksRequest = BalanceLocksRequestBuilder().buildRequest(for: chainAsset, accountId: accountId)
                let locks: BalanceLocks? = try await storageRequestPerformer.performRequest(balancesLocksRequest)

                await MainActor.run {
                    output?.didReceiveBalanceLocks(locks)
                }
            } catch {
                await MainActor.run {
                    output?.didReceiveBalanceLocksError(error)
                }
            }
        }
    }

    private func makeVestingClaimCall() -> ExtrinsicBuilderClosure {
        let closure: ExtrinsicBuilderClosure = { [weak self] builder in
            guard let self else { return builder }
            let claimCall = try self.callFactory.vestingClaim()
            return try builder.adding(call: claimCall)
        }

        return closure
    }

    private func fetchAccountInfo() {
        guard let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId else {
            output?.didReceiveAccountInfo(accountInfo: nil)
            return
        }

        accountInfoFetcher.fetch(for: chainAsset, accountId: accountId) { [weak self] _, accountInfo in
            DispatchQueue.main.async {
                self?.output?.didReceiveAccountInfo(accountInfo: accountInfo)
            }
        }
    }
}

// MARK: - ClaimCrowdloanRewardsInteractorInput

extension ClaimCrowdloanRewardsInteractor: ClaimCrowdloanRewardsInteractorInput {
    func setup(with output: ClaimCrowdloanRewardsInteractorOutput) {
        self.output = output

        priceProvider = priceLocalSubscriber.subscribeToPrice(for: chainAsset, listener: self)
        fetchBalanceLocks()
        fetchTokenLocks()
        fetchAccountInfo()
    }

    func estimateFee() {
        feeProxy.estimateFee(
            using: extrinsicService,
            reuseIdentifier: SubstrateCallPath.vestingClaim.callName,
            setupBy: makeVestingClaimCall()
        )
    }

    func submit() {
        extrinsicService.submit(
            makeVestingClaimCall(),
            signer: signer,
            runningIn: .main,
            completion: { [weak self] result in
                guard let self else { return }
                switch result {
                case let .success(txHash):
                    self.output?.didReceiveTxHash(txHash)
                case let .failure(error):
                    self.output?.didReceiveTxError(error)
                }
            }
        )
    }
}

extension ClaimCrowdloanRewardsInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>, for _: ExtrinsicFeeId) {
        switch result {
        case let .success(fee):
            output?.didReceiveFee(fee)
        case let .failure(error):
            output?.didReceiveFeeError(error)
        }
    }
}

extension ClaimCrowdloanRewardsInteractor: PriceLocalSubscriptionHandler {
    func handlePrice(result: Swift.Result<PriceData?, Error>, chainAsset _: ChainAsset) {
        switch result {
        case let .success(price):
            output?.didReceivePrice(price)
        case let .failure(error):
            output?.didReceivePriceError(error)
        }
    }
}
