import Foundation
import RobinHood

protocol SelectValidatorsStartParachainStrategyOutput: AnyObject {
    func didReceiveMaxDelegations(result: Result<Int, Error>)
    func didReceiveMaxTopDelegationsPerCandidate(result: Result<Int, Error>)
    func didReceiveMaxBottomDelegationsPerCandidate(result: Result<Int, Error>)
    func didReceiveSelectedCandidates(selectedCandidates: [ParachainStakingCandidateInfo])
    func didReceiveTopDelegations(delegations: [AccountAddress: ParachainStakingDelegations])
}

final class SelectValidatorsStartParachainStrategy: RuntimeConstantFetching {
    private let wallet: MetaAccountModel
    private let chainAsset: ChainAsset
    private let operationFactory: ParachainCollatorOperationFactory
    private let operationManager: OperationManagerProtocol
    private let runtimeService: RuntimeCodingServiceProtocol
    private weak var output: SelectValidatorsStartParachainStrategyOutput?

    init(
        wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        operationFactory: ParachainCollatorOperationFactory,
        operationManager: OperationManagerProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        output: SelectValidatorsStartParachainStrategyOutput?
    ) {
        self.wallet = wallet
        self.chainAsset = chainAsset
        self.operationFactory = operationFactory
        self.operationManager = operationManager
        self.runtimeService = runtimeService
        self.output = output
    }

    private func prepareRecommendedValidatorList() {
        guard let accountResponse = wallet.fetch(for: chainAsset.chain.accountRequest()) else { return }
        let wrapper = operationFactory.allElectedOperation()

        var allSelectedCollators: [ParachainStakingCandidateInfo] = []
        wrapper.targetOperation.completionBlock = {
            DispatchQueue.main.async {
                do {
                    if let result = try wrapper.targetOperation.extractNoCancellableResultData() {
                        allSelectedCollators = result
                    }
                } catch {
                    print("SelectValidatorsStartParachainStrategy.prepareRecommendedValidatorList error: ", error)
                }
            }
        }

        let runtimeOperation = runtimeService.fetchCoderFactoryOperation()
        let delegatorStateWrapper = operationFactory.createDelegatorStateOperation(
            dependingOn: runtimeOperation
        ) { [accountResponse.accountId] }
        delegatorStateWrapper.targetOperation.completionBlock = { [weak self] in
            guard let strongSelf = self else { return }
            self?.requestDelegatorState(
                for: accountResponse.accountId,
                chainAsset: strongSelf.chainAsset
            ) { delegatorState in
                let usedCollatorsIds: [AccountId] = delegatorState?.delegations.map(\.owner) ?? []
                let selectedCandidates: [ParachainStakingCandidateInfo]? = allSelectedCollators.filter { candidate in
                    !usedCollatorsIds.contains(candidate.owner)
                }
                self?.output?.didReceiveSelectedCandidates(selectedCandidates: selectedCandidates ?? [])

                if let collators = selectedCandidates {
                    self?.requestTopDelegationsForEachCollator(collators: collators)
                }
            }
        }
        delegatorStateWrapper.addDependency(wrapper: wrapper)

        operationManager.enqueue(
            operations: [runtimeOperation] + wrapper.allOperations + delegatorStateWrapper.allOperations,
            in: .transient
        )
    }

    private func requestTopDelegationsForEachCollator(collators: [ParachainStakingCandidateInfo]) {
        let topDelegationsOperation = operationFactory.collatorTopDelegations {
            collators.map(\.owner)
        }

        topDelegationsOperation.targetOperation.completionBlock = { [weak self] in
            do {
                let response = try topDelegationsOperation.targetOperation.extractNoCancellableResultData()

                guard let delegations = response else {
                    return
                }

                self?.output?.didReceiveTopDelegations(delegations: delegations)
            } catch {
                print("SelectValidatorsStartParachainStrategy.requestTopDelegationsForEachCollator error: ", error)
            }
        }

        operationManager.enqueue(operations: topDelegationsOperation.allOperations, in: .transient)
    }

    private func requestDelegatorState(
        for accountId: AccountId,
        chainAsset: ChainAsset,
        completionBlock: @escaping (ParachainStakingDelegatorState?) -> Void
    ) {
        let delegatorStateOperation = operationFactory.delegatorState {
            [accountId]
        }
        delegatorStateOperation.targetOperation.completionBlock = {
            do {
                let address = try AddressFactory.address(
                    for: accountId,
                    chainFormat: chainAsset.chain.chainFormat
                )

                let response = try delegatorStateOperation.targetOperation.extractNoCancellableResultData()
                let delegatorState = response?[address]

                completionBlock(delegatorState)
            } catch {
                print("SelectValidatorsStartParachainStrategy.requestDelegatorState error: ", error)
            }
        }

        operationManager.enqueue(operations: delegatorStateOperation.allOperations, in: .transient)
    }
}

extension SelectValidatorsStartParachainStrategy: SelectValidatorsStartStrategy {
    func setup() {
        prepareRecommendedValidatorList()

        fetchConstant(
            for: .maxDelegationsPerDelegator,
            runtimeCodingService: runtimeService,
            operationManager: operationManager
        ) { [weak self] (result: Result<Int, Error>) in
            self?.output?.didReceiveMaxDelegations(result: result)
        }

        fetchConstant(
            for: .maxTopDelegationsPerCandidate,
            runtimeCodingService: runtimeService,
            operationManager: operationManager
        ) { [weak self] (result: Result<Int, Error>) in
            self?.output?.didReceiveMaxTopDelegationsPerCandidate(result: result)
        }

        fetchConstant(
            for: .maxBottomDelegationsPerCandidate,
            runtimeCodingService: runtimeService,
            operationManager: operationManager
        ) { [weak self] (result: Result<Int, Error>) in
            self?.output?.didReceiveMaxBottomDelegationsPerCandidate(result: result)
        }
    }
}
