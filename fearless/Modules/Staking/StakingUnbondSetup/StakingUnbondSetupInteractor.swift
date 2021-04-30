import UIKit
import SoraKeystore
import RobinHood
import BigInt

final class StakingUnbondSetupInteractor {
    weak var presenter: StakingUnbondSetupInteractorOutputProtocol!

    let singleValueProviderFactory: SingleValueProviderFactoryProtocol
    let substrateProviderFactory: SubstrateDataProviderFactoryProtocol
    let settings: SettingsManagerProtocol
    let runtimeService: RuntimeCodingServiceProtocol
    let operationManager: OperationManagerProtocol
    let assetId: WalletAssetId

    var stashItemProvider: StreamableProvider<StashItem>?
    var electionStatusProvider: AnyDataProvider<DecodedElectionStatus>?
    var ledgerProvider: AnyDataProvider<DecodedLedgerInfo>?
    var accountInfoProvider: AnyDataProvider<DecodedAccountInfo>?
    var priceProvider: AnySingleValueProvider<PriceData>?

    init(
        assetId: WalletAssetId,
        singleValueProviderFactory: SingleValueProviderFactoryProtocol,
        substrateProviderFactory: SubstrateDataProviderFactoryProtocol,
        settings: SettingsManagerProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        operationManager: OperationManagerProtocol
    ) {
        self.singleValueProviderFactory = singleValueProviderFactory
        self.substrateProviderFactory = substrateProviderFactory
        self.settings = settings
        self.runtimeService = runtimeService
        self.operationManager = operationManager
        self.assetId = assetId
    }

    private func fetchConstant<T: LosslessStringConvertible & Equatable>(
        for path: ConstantCodingPath,
        closure: @escaping (Result<T, Error>) -> Void
    ) {
        let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()
        let constOperation = PrimitiveConstantOperation<T>(path: path)
        constOperation.configurationBlock = {
            do {
                constOperation.codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            } catch {
                constOperation.result = .failure(error)
            }
        }

        constOperation.addDependency(codingFactoryOperation)

        constOperation.completionBlock = {
            DispatchQueue.main.async {
                if let result = constOperation.result {
                    closure(result)
                } else {
                    closure(.failure(BaseOperationError.parentOperationCancelled))
                }
            }
        }

        operationManager.enqueue(operations: [constOperation, codingFactoryOperation], in: .transient)
    }
}

extension StakingUnbondSetupInteractor: StakingUnbondSetupInteractorInputProtocol {
    func setup() {
        if let address = settings.selectedAccount?.address {
            stashItemProvider = subscribeToStashItemProvider(for: address)
        }

        priceProvider = subscribeToPriceProvider(for: assetId)

        fetchConstant(for: .lockUpPeriod) { [weak self] (result: Result<UInt32, Error>) in
            self?.presenter.didReceiveBondingDuration(result: result)
        }

        fetchConstant(for: .existentialDeposit) { [weak self] (result: Result<BigUInt, Error>) in
            self?.presenter.didReceiveExistentialDeposit(result: result)
        }
    }
}

extension StakingUnbondSetupInteractor: SingleValueProviderSubscriber, SingleValueSubscriptionHandler,
    SubstrateProviderSubscriber, SubstrateProviderSubscriptionHandler,
    AnyProviderAutoCleaning {
    func handleStashItem(result: Result<StashItem?, Error>) {
        do {
            let maybeStashItem = try result.get()

            clear(dataProvider: &accountInfoProvider)
            clear(dataProvider: &ledgerProvider)

            if let stashItem = maybeStashItem {
                ledgerProvider = subscribeToLedgerInfoProvider(
                    for: stashItem.controller,
                    runtimeService: runtimeService
                )

                accountInfoProvider = subscribeToAccountInfoProvider(
                    for: stashItem.controller,
                    runtimeService: runtimeService
                )
            } else {
                presenter.didReceiveStakingLedger(result: .success(nil))
                presenter.didReceiveAccountInfo(result: .success(nil))
            }

        } catch {
            presenter.didReceiveAccountInfo(result: .failure(error))
            presenter.didReceiveStakingLedger(result: .failure(error))
        }
    }

    func handleAccountInfo(result: Result<DyAccountInfo?, Error>, address _: AccountAddress) {
        presenter.didReceiveAccountInfo(result: result)
    }

    func handleLedgerInfo(result: Result<DyStakingLedger?, Error>, address _: AccountAddress) {
        presenter.didReceiveStakingLedger(result: result)
    }

    func handlePrice(result: Result<PriceData?, Error>, for _: WalletAssetId) {
        presenter.didReceivePriceData(result: result)
    }
}
