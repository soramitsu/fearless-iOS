import RobinHood
import IrohaCrypto

final class YourValidatorInfoInteractor: ValidatorInfoInteractorBase {
    private let chain: ChainModel
    private let selectedAccount: MetaAccountModel
    private let validatorOperationFactory: ValidatorOperationFactoryProtocol
    private let operationManager: OperationManagerProtocol
    private let accountAddress: AccountAddress

    private lazy var addressFactory = SS58AddressFactory()

    init(
        accountAddress: AccountAddress,
        selectedAccount: MetaAccountModel,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        asset: AssetModel,
        chain: ChainModel,
        validatorOperationFactory: ValidatorOperationFactoryProtocol,
        operationManager: OperationManagerProtocol
    ) {
        self.accountAddress = accountAddress
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
            guard let accountId = try? addressFactory.accountId(fromAddress: accountAddress, type: chain.addressPrefix) else {
                throw (ChainAccountFetchingError.accountNotExists)
            }

            presenter.didStartLoadingValidatorInfo()

            let operation = validatorOperationFactory.wannabeValidatorsOperation(for: [accountId])

            operation.targetOperation.completionBlock = { [weak self] in
                guard let self = self else {
                    return
                }
                DispatchQueue.main.async {
                    do {
                        if let validatorInfo =
                            try operation.targetOperation.extractNoCancellableResultData().first {
                            self.presenter.didReceiveValidatorInfo(result: .success(validatorInfo))
                        } else {
                            let validatorInfo = SelectedValidatorInfo(address: self.accountAddress)
                            self.presenter.didReceiveValidatorInfo(result: .success(validatorInfo))
                        }
                    } catch {
                        self.presenter.didReceiveValidatorInfo(result: .failure(error))
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
