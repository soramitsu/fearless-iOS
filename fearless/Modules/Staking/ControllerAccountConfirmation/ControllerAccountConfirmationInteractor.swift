import UIKit

final class ControllerAccountConfirmationInteractor {
    weak var presenter: ControllerAccountConfirmationInteractorOutputProtocol!

    let singleValueProviderFactory: SingleValueProviderFactoryProtocol
    private let feeProxy: ExtrinsicFeeProxyProtocol
    private let extrinsicService: ExtrinsicServiceProtocol
    private let signingWrapper: SigningWrapperProtocol
    private let assetId: WalletAssetId
    private let controllerAccountItem: AccountItem
    private lazy var callFactory = SubstrateCallFactory()

    private var priceProvider: AnySingleValueProvider<PriceData>?

    init(
        singleValueProviderFactory: SingleValueProviderFactoryProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        signingWrapper: SigningWrapperProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        assetId: WalletAssetId,
        controllerAccountItem: AccountItem
    ) {
        self.singleValueProviderFactory = singleValueProviderFactory
        self.extrinsicService = extrinsicService
        self.signingWrapper = signingWrapper
        self.feeProxy = feeProxy
        self.assetId = assetId
        self.controllerAccountItem = controllerAccountItem
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
}

extension ControllerAccountConfirmationInteractor: SingleValueProviderSubscriber, SingleValueSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, for _: WalletAssetId) {
        presenter.didReceivePriceData(result: result)
    }
}

extension ControllerAccountConfirmationInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>, for _: ExtrinsicFeeId) {
        presenter.didReceiveFee(result: result)
    }
}
