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
        storageRequestPerformer: StorageRequestPerformer
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

        self.feeProxy.delegate = self
    }

    private func fetchTokenLocks() {
        guard
//            let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId,
            let accountId = try? "0xb6886973c891bf20892bfe376d58c89e42f42163a47816c2b064ac7e78528f25".toAccountId(),
            let currencyId = chainAsset.currencyId
        else {
            output?.didReceiveBalanceLocksError(ChainAccountFetchingError.accountNotExists)
            return
        }

        Task {
            do {
                let tokensLocksRequest = TokensLocksRequest(accountId: accountId, currencyId: currencyId)
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
        guard let accountId = try? "0xb6886973c891bf20892bfe376d58c89e42f42163a47816c2b064ac7e78528f25".toAccountId() else {
//        guard let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId else {
            output?.didReceiveBalanceLocksError(ChainAccountFetchingError.accountNotExists)
            return
        }

        Task {
            do {
                let balancesLocksRequest = BalancesLocksRequest(accountId: accountId)
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

    private func fetchVestingSchedule() {
        guard let accountId = try? "0xb6886973c891bf20892bfe376d58c89e42f42163a47816c2b064ac7e78528f25".toAccountId() else {
//        guard let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId else {
            output?.didReceiveVestingScheduleError(ChainAccountFetchingError.accountNotExists)
            return
        }

        Task {
            let request = VestingSchedulesRequest(accountId: accountId)

            do {
                let vestingSchedule: [VestingSchedule]? = try await storageRequestPerformer.performRequest(request)
                fetchCurrentBlock(forRelaychain: vestingSchedule?.first?.start != 0)

                await MainActor.run(body: {
                    output?.didReceiveVestingSchedule(vestingSchedule?.first)
                })
            } catch {
                await MainActor.run(body: {
                    output?.didReceiveVestingScheduleError(error)
                })
            }
        }
    }

    private func fetchVestingVesting() {
        guard let accountId = try? "0xb6886973c891bf20892bfe376d58c89e42f42163a47816c2b064ac7e78528f25".toAccountId() else {
//        guard let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId else {
            output?.didReceiveVestingScheduleError(ChainAccountFetchingError.accountNotExists)
            return
        }

        Task {
            let request = VestingVestingRequest(accountId: accountId)

            do {
                let vesting: [VestingVesting]? = try await storageRequestPerformer.performRequest(request)
                fetchCurrentBlock(forRelaychain: false)

                await MainActor.run(body: {
                    output?.didReceiveVestingVesting(vesting?.first)
                })
            } catch {
                await MainActor.run(body: {
                    output?.didReceiveVestingVestingError(error)
                })
            }
        }
    }

    private func fetchCurrentBlock(forRelaychain: Bool) {
        var chainId: ChainModel.Id

        if forRelaychain {
            switch chainAsset.defineEcosystem() {
            case .polkadot:
                chainId = Chain.polkadot.genesisHash
            case .kusama:
                chainId = Chain.kusama.genesisHash
            default:
                chainId = chainAsset.chain.chainId
            }
        } else {
            chainId = chainAsset.chain.chainId
        }

        guard
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainId),
            let connection = chainRegistry.getConnection(for: chainId)
        else {
            return
        }

        Task {
            do {
                let currentBlock = try await networkInfoFetcher.fetchCurrentBlock(runtimeService: runtimeService, connection: connection)
                DispatchQueue.main.async { [weak self] in
                    self?.output?.didReceiveCurrenBlock(currentBlock)
                }
            } catch {
                DispatchQueue.main.async { [weak self] in
                    self?.output?.didReceiveCurrentBlockError(error)
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
}

// MARK: - ClaimCrowdloanRewardsInteractorInput

extension ClaimCrowdloanRewardsInteractor: ClaimCrowdloanRewardsInteractorInput {
    func setup(with output: ClaimCrowdloanRewardsInteractorOutput) {
        self.output = output

        priceProvider = priceLocalSubscriber.subscribeToPrice(for: chainAsset, listener: self)
        fetchBalanceLocks()
        fetchTokenLocks()
        fetchVestingSchedule()
        fetchVestingVesting()
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
                    output?.didReceiveTxHash(txHash)
                case let .failure(error):
                    output?.didReceiveTxError(error)
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
