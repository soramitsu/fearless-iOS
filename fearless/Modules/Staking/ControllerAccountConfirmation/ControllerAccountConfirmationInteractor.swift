import UIKit
import RobinHood

final class ControllerAccountConfirmationInteractor {
    weak var presenter: ControllerAccountConfirmationInteractorOutputProtocol!

    let singleValueProviderFactory: SingleValueProviderFactoryProtocol
    let substrateProviderFactory: SubstrateDataProviderFactoryProtocol
    private let selectedAccountAddress: AccountAddress
    private let feeProxy: ExtrinsicFeeProxyProtocol
    private let extrinsicService: ExtrinsicServiceProtocol
    private let signingWrapper: SigningWrapperProtocol
    private let assetId: WalletAssetId
    private let controllerAccountItem: AccountItem
    private let accountRepository: AnyDataProviderRepository<AccountItem>
    private let operationManager: OperationManagerProtocol
    private lazy var callFactory = SubstrateCallFactory()

    private var stashItemProvider: StreamableProvider<StashItem>?
    private var priceProvider: AnySingleValueProvider<PriceData>?

    init(
        singleValueProviderFactory: SingleValueProviderFactoryProtocol,
        substrateProviderFactory: SubstrateDataProviderFactoryProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        signingWrapper: SigningWrapperProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        assetId: WalletAssetId,
        controllerAccountItem: AccountItem,
        accountRepository: AnyDataProviderRepository<AccountItem>,
        operationManager: OperationManagerProtocol,
        selectedAccountAddress: AccountAddress
    ) {
        self.singleValueProviderFactory = singleValueProviderFactory
        self.substrateProviderFactory = substrateProviderFactory
        self.extrinsicService = extrinsicService
        self.signingWrapper = signingWrapper
        self.feeProxy = feeProxy
        self.assetId = assetId
        self.controllerAccountItem = controllerAccountItem
        self.accountRepository = accountRepository
        self.operationManager = operationManager
        self.selectedAccountAddress = selectedAccountAddress
    }

    private func estimateFee() {
        do {
            let setController = try callFactory.setController(controllerAccountItem.address)
            let identifier = setController.callName + controllerAccountItem.identifier

            feeProxy.estimateFee(using: extrinsicService, reuseIdentifier: identifier) { builder in
                try builder.adding(call: setController)
            }
        } catch {
            presenter.didReceiveFee(result: .failure(error))
        }
    }
}

extension ControllerAccountConfirmationInteractor: ControllerAccountConfirmationInteractorInputProtocol {
    func setup() {
        stashItemProvider = subscribeToStashItemProvider(for: selectedAccountAddress)
        priceProvider = subscribeToPriceProvider(for: assetId)
        estimateFee()
        feeProxy.delegate = self
    }

    func confirm() {
        do {
            let setController = try callFactory.setController(controllerAccountItem.address)

            extrinsicService.submit(
                { builder in
                    try builder.adding(call: setController)
                },
                signer: signingWrapper,
                runningIn: .main,
                completion: { [weak self] result in
                    self?.presenter.didConfirmed(result: result)
                }
            )
        } catch {
            presenter.didConfirmed(result: .failure(error))
        }
    }

    func fetchStashAccountItem(for address: AccountAddress) {
        fetchAccount(
            for: address,
            from: accountRepository,
            operationManager: operationManager
        ) { [weak self] result in
            self?.presenter.didReceiveStashAccount(result: result)
        }
    }
}

extension ControllerAccountConfirmationInteractor: SubstrateProviderSubscriber, SubstrateProviderSubscriptionHandler,
    SingleValueProviderSubscriber, SingleValueSubscriptionHandler, AccountFetching {
    func handleStashItem(result: Result<StashItem?, Error>) {
        presenter.didReceiveStashItem(result: result)
    }

    func handlePrice(result: Result<PriceData?, Error>, for _: WalletAssetId) {
        presenter.didReceivePriceData(result: result)
    }
}

extension ControllerAccountConfirmationInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>, for _: ExtrinsicFeeId) {
        presenter.didReceiveFee(result: result)
    }
}
