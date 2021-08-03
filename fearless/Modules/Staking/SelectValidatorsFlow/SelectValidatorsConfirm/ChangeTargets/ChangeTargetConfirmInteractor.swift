import Foundation
import RobinHood
import SoraKeystore

final class ChangeTargetsConfirmInteractor: SelectValidatorsConfirmInteractorBase {
    let nomination: PreparedNomination<ExistingBonding>
    let repository: AnyDataProviderRepository<AccountItem>

    init(
        singleValueProviderFactory: SingleValueProviderFactoryProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        durationOperationFactory: StakingDurationOperationFactoryProtocol,
        operationManager: OperationManagerProtocol,
        signer: SigningWrapperProtocol,
        chain: Chain,
        assetId: WalletAssetId,
        repository: AnyDataProviderRepository<AccountItem>,
        nomination: PreparedNomination<ExistingBonding>
    ) {
        self.nomination = nomination
        self.repository = repository

        super.init(
            balanceAccountAddress: nomination.bonding.controllerAccount.address,
            singleValueProviderFactory: singleValueProviderFactory,
            extrinsicService: extrinsicService,
            runtimeService: runtimeService,
            durationOperationFactory: durationOperationFactory,
            operationManager: operationManager,
            signer: signer,
            chain: chain,
            assetId: assetId
        )
    }

    private func createRewardDestinationOperation(
        for payoutAddress: String
    ) -> CompoundOperationWrapper<RewardDestination<DisplayAddress>> {
        let accountFetchOperation = repository.fetchOperation(
            by: payoutAddress,
            options: RepositoryFetchOptions()
        )
        let mapOperation: BaseOperation<RewardDestination<DisplayAddress>> = ClosureOperation {
            if let accountItem = try accountFetchOperation.extractNoCancellableResultData() {
                let displayAddress = DisplayAddress(
                    address: accountItem.address,
                    username: accountItem.username
                )

                return RewardDestination.payout(account: displayAddress)
            } else {
                let displayAddress = DisplayAddress(
                    address: payoutAddress,
                    username: payoutAddress
                )

                return RewardDestination.payout(account: displayAddress)
            }
        }

        mapOperation.addDependency(accountFetchOperation)

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: [accountFetchOperation]
        )
    }

    private func provideConfirmationModel() {
        let rewardDestWrapper: CompoundOperationWrapper<RewardDestination<DisplayAddress>> = {
            switch nomination.bonding.rewardDestination {
            case .restake:
                return CompoundOperationWrapper.createWithResult(RewardDestination<DisplayAddress>.restake)
            case let .payout(address):
                return createRewardDestinationOperation(for: address)
            }
        }()

        let currentNomination = nomination

        let mapOperation: BaseOperation<SelectValidatorsConfirmationModel> = ClosureOperation {
            let controller = currentNomination.bonding.controllerAccount
            let rewardDestination = try rewardDestWrapper.targetOperation.extractNoCancellableResultData()

            let controllerDisplayAddress = DisplayAddress(
                address: controller.address,
                username: controller.username
            )

            return SelectValidatorsConfirmationModel(
                wallet: controllerDisplayAddress,
                amount: currentNomination.bonding.amount,
                rewardDestination: rewardDestination,
                targets: currentNomination.targets,
                maxTargets: currentNomination.maxTargets
            )
        }

        let dependencies = rewardDestWrapper.allOperations

        dependencies.forEach { mapOperation.addDependency($0) }

        mapOperation.completionBlock = {
            DispatchQueue.main.async {
                do {
                    let confirmationModel = try mapOperation.extractNoCancellableResultData()
                    self.presenter.didReceiveModel(result: .success(confirmationModel))
                } catch {
                    self.presenter.didReceiveModel(result: .failure(error))
                }
            }
        }

        operationManager.enqueue(operations: dependencies + [mapOperation], in: .transient)
    }

    private func createExtrinsicBuilderClosure() -> ExtrinsicBuilderClosure? {
        let targets = nomination.targets

        let closure: ExtrinsicBuilderClosure = { builder in
            let callFactory = SubstrateCallFactory()

            let nominateCall = try callFactory.nominate(targets: targets)

            return try builder
                .adding(call: nominateCall)
        }

        return closure
    }

    override func setup() {
        provideConfirmationModel()

        super.setup()
    }

    override func estimateFee() {
        guard let closure = createExtrinsicBuilderClosure() else {
            return
        }

        extrinsicService.estimateFee(closure, runningIn: .main) { [weak self] result in
            switch result {
            case let .success(info):
                self?.presenter.didReceive(paymentInfo: info)
            case let .failure(error):
                self?.presenter.didReceive(feeError: error)
            }
        }
    }

    override func submitNomination(for lastBalance: Decimal, lastFee: Decimal) {
        guard lastBalance >= lastFee else {
            presenter.didFailNomination(error: SelectValidatorsConfirmError.notEnoughFunds)
            return
        }

        guard !nomination.targets.isEmpty else {
            presenter.didFailNomination(error: SelectValidatorsConfirmError.extrinsicFailed)
            return
        }

        guard let closure = createExtrinsicBuilderClosure() else {
            return
        }

        presenter.didStartNomination()

        extrinsicService.submit(
            closure,
            signer: signer,
            runningIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(txHash):
                self?.presenter.didCompleteNomination(txHash: txHash)
            case let .failure(error):
                self?.presenter.didFailNomination(error: error)
            }
        }
    }
}
