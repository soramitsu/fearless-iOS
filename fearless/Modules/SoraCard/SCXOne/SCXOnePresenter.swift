import Foundation
import SoraFoundation

final class SCXOnePresenter {
    // MARK: Private properties

    private weak var view: SCXOneViewInput?
    private let router: SCXOneRouterInput
    private let interactor: SCXOneInteractorInput
    private let wallet: MetaAccountModel
    private let chainAsset: ChainAsset

    // MARK: - Constructors

    init(
        interactor: SCXOneInteractorInput,
        router: SCXOneRouterInput,
        wallet: MetaAccountModel,
        chainAsset: ChainAsset
    ) {
        self.interactor = interactor
        self.router = router
        self.wallet = wallet
        self.chainAsset = chainAsset
    }

    // MARK: - Private methods
}

// MARK: - SCXOneViewOutput

extension SCXOnePresenter: SCXOneViewOutput {
    func didLoad(view: SCXOneViewInput) {
        self.view = view
        interactor.setup(with: self)
        if let address = wallet.fetch(for: chainAsset.chain.accountRequest())?.toAddress() {
            let paymentId = UUID().uuidString
            let htmlString = XOneHtmlStringBuilder.build(with: address, paymentId: paymentId)
            view.startLoading(with: htmlString)
            interactor.checkStatus(paymentId: paymentId)
        }
    }
}

// MARK: - SCXOneInteractorOutput

extension SCXOnePresenter: SCXOneInteractorOutput {}

extension SCXOnePresenter: SCXOneModuleInput {}
