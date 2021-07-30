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

    private func fetchWannabeValidatorInfo() {
        guard let accountId = try? addressFactory.accountId(from: accountAddress) else {
            return
        }

        let operation = validatorOperationFactory.wannabeValidatorsOperation(for: [accountId])

        operation.targetOperation.completionBlock = {
            DispatchQueue.main.async { [weak self] in
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
    }

    private func fetchValidatorInfo() {
        let operation = validatorOperationFactory.allElectedOperation()

        operation.targetOperation.completionBlock = {
            DispatchQueue.main.async { [weak self] in
                do {
                    let electedValidatorList = try operation.targetOperation.extractNoCancellableResultData()
                    let searchValidatorResult = electedValidatorList.filter { validatorInfo in
                        validatorInfo.address == self?.accountAddress
                    }

                    if let electedValidatorInfo = searchValidatorResult.first {
                        let validatorInfo = electedValidatorInfo.toSelected(for: nil)
                        self?.presenter.didReceiveValidatorInfo(result: .success(validatorInfo))
                    } else {
                        self?.fetchWannabeValidatorInfo()
                    }
                } catch {
                    self?.fetchWannabeValidatorInfo()
                }
            }
        }

        operationManager.enqueue(operations: operation.allOperations, in: .transient)
    }

    override func setup() {
        super.setup()
        fetchValidatorInfo()
    }
}
