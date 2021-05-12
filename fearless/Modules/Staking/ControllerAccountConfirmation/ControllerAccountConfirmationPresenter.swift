import Foundation
import SoraFoundation
import FearlessUtils
import BigInt

final class ControllerAccountConfirmationPresenter {
    weak var view: ControllerAccountConfirmationViewProtocol?
    var wireframe: ControllerAccountConfirmationWireframeProtocol!
    var interactor: ControllerAccountConfirmationInteractorInputProtocol!

    let iconGenerator: IconGenerating
    private let stashAccountItem: AccountItem
    private let controllerAccountItem: AccountItem
    private let chain: Chain
    private let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    private let logger: LoggerProtocol?

    private var fee: Decimal?
    private var priceData: PriceData?

    init(
        stashAccountItem: AccountItem,
        controllerAccountItem: AccountItem,
        chain: Chain,
        iconGenerator: IconGenerating,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.stashAccountItem = stashAccountItem
        self.controllerAccountItem = controllerAccountItem
        self.chain = chain
        self.iconGenerator = iconGenerator
        self.balanceViewModelFactory = balanceViewModelFactory
        self.logger = logger
    }

    private func setupView() {
        let viewModel = LocalizableResource<ControllerAccountConfirmationVM> { locale in
            let stashViewModel = self.createAccountInfoViewModel(
                self.stashAccountItem,
                title: R.string.localizable.stackingStashAccount(preferredLanguages: locale.rLanguages)
            )
            let controllerViewModel = self.createAccountInfoViewModel(
                self.controllerAccountItem,
                title: R.string.localizable.stakingControllerAccountTitle(preferredLanguages: locale.rLanguages)
            )

            return ControllerAccountConfirmationVM(
                stashViewModel: stashViewModel,
                controllerViewModel: controllerViewModel
            )
        }
        view?.reload(with: viewModel)
    }

    private func createAccountInfoViewModel(_ accountItem: AccountItem, title: String) -> AccountInfoViewModel {
        let address = accountItem.address
        let icon = try? iconGenerator
            .generateFromAddress(address)
            .imageWithFillColor(
                R.color.colorWhite()!,
                size: UIConstants.smallAddressIconSize,
                contentScale: UIScreen.main.scale
            )
        return AccountInfoViewModel(
            title: title,
            address: address,
            name: accountItem.username,
            icon: icon
        )
    }

    private func provideFeeViewModel() {
        if let fee = fee {
            let feeViewModel = balanceViewModelFactory.balanceFromPrice(fee, priceData: priceData)
            view?.didReceiveFee(viewModel: feeViewModel)
        } else {
            view?.didReceiveFee(viewModel: nil)
        }
    }
}

extension ControllerAccountConfirmationPresenter: ControllerAccountConfirmationPresenterProtocol {
    func setup() {
        setupView()
        provideFeeViewModel()
        interactor.setup()
    }

    func handleStashAction() {
        presentAccountOptions(for: stashAccountItem.address)
    }

    func handleControllerAction() {
        presentAccountOptions(for: controllerAccountItem.address)
    }

    func confirm() {
        view?.didStartLoading()
        interactor.confirm()
    }

    private func presentAccountOptions(for address: AccountAddress) {
        guard let view = view else { return }
        wireframe.presentAccountOptions(
            from: view,
            address: address,
            chain: chain,
            locale: view.localizationManager?.selectedLocale ?? .current
        )
    }
}

extension ControllerAccountConfirmationPresenter: ControllerAccountConfirmationInteractorOutputProtocol {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>) {
        switch result {
        case let .success(dispatchInfo):
            if let feeValue = BigUInt(dispatchInfo.fee) {
                fee = Decimal.fromSubstrateAmount(feeValue, precision: chain.addressType.precision)
            } else {
                fee = nil
            }

            provideFeeViewModel()
        case let .failure(error):
            logger?.error("Did receive fee error: \(error)")
        }
    }

    func didReceivePriceData(result: Result<PriceData?, Error>) {
        switch result {
        case let .success(priceData):
            self.priceData = priceData

            provideFeeViewModel()
        case let .failure(error):
            logger?.error("Did receive price data error: \(error)")
        }
    }

    func didConfirmed(result: Result<String, Error>) {
        view?.didStopLoading()

        guard let view = view else {
            return
        }

        switch result {
        case .success:
            wireframe.complete(from: view)
        case .failure:
            wireframe.presentExtrinsicFailed(from: view, locale: view.localizationManager?.selectedLocale)
        }
    }
}
