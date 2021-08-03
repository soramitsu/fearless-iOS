import RobinHood
import IrohaCrypto

final class YourValidatorInfoInteractor: ValidatorInfoInteractorBase {
    private let accountAddress: AccountAddress
    private let validatorOperationFactory: ValidatorOperationFactoryProtocol
    private let operationManager: OperationManagerProtocol

    private lazy var addressFactory = SS58AddressFactory()

    init(
        accountAddress: AccountAddress,
        singleValueProviderFactory: SingleValueProviderFactoryProtocol,
        walletAssetId: WalletAssetId,
        validatorOperationFactory: ValidatorOperationFactoryProtocol,
        operationManager: OperationManagerProtocol
    ) {
        self.accountAddress = accountAddress
        self.validatorOperationFactory = validatorOperationFactory
        self.operationManager = operationManager

        super.init(
            singleValueProviderFactory: singleValueProviderFactory,
            walletAssetId: walletAssetId
        )
    }

    private func fetchValidatorInfo() {
        do {
            let accountId = try addressFactory.accountId(from: accountAddress)

            presenter.didStartLoadingValidatorInfo()

            let operation = validatorOperationFactory.wannabeValidatorsOperation(for: [accountId])

            operation.targetOperation.completionBlock = { [weak self] in
                DispatchQueue.main.async {
                    do {
                        if let validatorInfo =
                            try operation.targetOperation.extractNoCancellableResultData().first {
                            self?.presenter.didReceiveValidatorInfo(result: .success(validatorInfo))
                        } else {
                            let validatorInfo = SelectedValidatorInfo(address: self?.accountAddress ?? "")
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
