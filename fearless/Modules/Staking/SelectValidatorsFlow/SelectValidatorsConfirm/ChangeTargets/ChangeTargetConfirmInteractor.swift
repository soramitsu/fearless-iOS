import Foundation
import RobinHood
import SoraKeystore

final class ChangeTargetsConfirmInteractor: SelectValidatorsConfirmInteractorBase {
    let nomination: PreparedNomination<ExistingBonding>

    init(
        extrinsicService: ExtrinsicServiceProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        durationOperationFactory _: StakingDurationOperationFactoryProtocol,
        operationManager: OperationManagerProtocol,
        signer: SigningWrapperProtocol,
        chainAsset: ChainAsset,
        selectedAccount: MetaAccountModel,
        nomination: PreparedNomination<ExistingBonding>,
        stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    ) {
        self.nomination = nomination

        super.init(
            balanceAccountId: nomination.bonding.controllerAccount.accountId,
            stakingLocalSubscriptionFactory: stakingLocalSubscriptionFactory,
            accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapter(
                walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
                selectedMetaAccount: selectedAccount
            ),
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            extrinsicService: extrinsicService,
            runtimeService: runtimeService,
            durationOperationFactory: StakingDurationOperationFactory(),
            operationManager: operationManager,
            signer: signer,
            chainAsset: chainAsset,
            selectedAccount: selectedAccount
        )
    }

    private func createRewardDestinationOperation(
        for payoutAddress: String
    ) -> CompoundOperationWrapper<RewardDestination<DisplayAddress>> {
        let mapOperation: BaseOperation<RewardDestination<DisplayAddress>> = ClosureOperation { [weak self] in
            guard let strongSelf = self else {
                throw BaseOperationError.parentOperationCancelled
            }
            let displayAddress = DisplayAddress(
                address: strongSelf.selectedAccount.fetch(
                    for: strongSelf.chainAsset.chain.accountRequest()
                )?.toAddress() ?? payoutAddress,
                username: strongSelf.selectedAccount.name
            )

            return RewardDestination.payout(account: displayAddress)
        }

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: []
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
                address: controller.toAddress() ?? "",
                username: controller.name
            )

            return SelectValidatorsConfirmationModel(
                wallet: controllerDisplayAddress,
                amount: currentNomination.bonding.amount,
                rewardDestination: rewardDestination,
                targets: currentNomination.targets,
                maxTargets: currentNomination.maxTargets,
                hasExistingBond: true,
                hasExistingNomination: currentNomination.bonding.selectedTargets != nil
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

    override func submitNomination() {
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
