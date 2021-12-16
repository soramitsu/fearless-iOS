import RobinHood
import IrohaCrypto

final class YourValidatorInfoInteractor: ValidatorInfoInteractorBase {
    private let chain: ChainModel
    private let selectedAccount: MetaAccountModel
    private let validatorOperationFactory: ValidatorOperationFactoryProtocol
    private let operationManager: OperationManagerProtocol

    private lazy var addressFactory = SS58AddressFactory()

    init(
        selectedAccount: MetaAccountModel,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        asset: AssetModel,
        chain: ChainModel,
        validatorOperationFactory: ValidatorOperationFactoryProtocol,
        operationManager: OperationManagerProtocol
    ) {
        self.chain = chain
        self.selectedAccount = selectedAccount
        self.validatorOperationFactory = validatorOperationFactory
        self.operationManager = operationManager

        super.init(
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            asset: asset
        )
    }

    private func fetchValidatorInfo() {
        do {
            guard let accountId = selectedAccount.fetch(for: chain.accountRequest())?.accountId else {
                throw (ChainAccountFetchingError.accountNotExists)
            }

            presenter.didStartLoadingValidatorInfo()

            let operation = validatorOperationFactory.wannabeValidatorsOperation(for: [accountId])

            operation.targetOperation.completionBlock = { [weak self] in
                DispatchQueue.main.async {
                    do {
                        if let validatorInfo =
                            try operation.targetOperation.extractNoCancellableResultData().first {
                            self?.presenter.didReceiveValidatorInfo(result: .success(validatorInfo))
                        } else {
                            let validatorInfo = SelectedValidatorInfo(address: self?.selectedAccount.fetch(for: self?.chain.accountRequest())?.toAddress() ?? "")
                            self?.presenter.didReceiveValidatorInfo(result: .success(validatorInfo))
                        }
                    } catch {
                        self?.presenter.didReceiveValidatorInfo(result: .failure(error))
                    }
                }
            }

            operationManager.enqueue(operations: operation.allOperations, in: .transient)
        } catch {
            presenter.didReceiveValidatorInfo(result: .failure(error))
        }
    }

    override func setup() {
        super.setup()

        fetchValidatorInfo()
    }

    override func reload() {
        super.reload()
        fetchValidatorInfo()
    }
}
