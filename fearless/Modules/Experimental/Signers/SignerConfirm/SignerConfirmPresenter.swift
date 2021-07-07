import Foundation
import BigInt
import SoraFoundation

final class SignerConfirmPresenter {
    weak var view: SignerConfirmViewProtocol?
    let wireframe: SignerConfirmWireframeProtocol
    let interactor: SignerConfirmInteractorInputProtocol
    let viewModelFactory: SignerConfirmViewModelFactoryProtocol
    let chain: Chain
    let selectedAccount: AccountItem
    let dataValidatingFactory: BaseDataValidatingFactoryProtocol

    private var balance: Decimal?
    private var priceData: PriceData?
    private var confirmationData: SignerConfirmation?
    private var fee: Decimal?

    init(
        interactor: SignerConfirmInteractorInputProtocol,
        wireframe: SignerConfirmWireframeProtocol,
        viewModelFactory: SignerConfirmViewModelFactoryProtocol,
        chain: Chain,
        selectedAccount: AccountItem,
        dataValidatingFactory: BaseDataValidatingFactoryProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.chain = chain
        self.selectedAccount = selectedAccount
        self.dataValidatingFactory = dataValidatingFactory
        self.localizationManager = localizationManager
    }

    private func provideCallViewModel() {
        guard let confirmation = confirmationData else {
            return
        }

        do {
            let viewModel = try viewModelFactory.createCallViewModel(
                from: confirmation,
                account: selectedAccount,
                priceData: priceData,
                locale: selectedLocale
            )

            view?.didReceiveCall(viewModel: viewModel)
        } catch {
            wireframe.presentErrorOrUndefined(error: error, from: view, locale: selectedLocale)
        }
    }

    private func provideFeeViewModel() {
        guard let confirmation = confirmationData, let fee = fee else {
            return
        }

        let viewModel = viewModelFactory.createFeeViewModel(
            from: confirmation,
            fee: fee,
            priceData: priceData,
            locale: selectedLocale
        )

        view?.didReceiveFee(viewModel: viewModel)
    }

    func presentAccountOptions() {
        guard let view = view else {
            return
        }

        wireframe.presentAccountOptions(
            from: view,
            address: selectedAccount.address,
            chain: chain,
            locale: view.selectedLocale
        )
    }
}

extension SignerConfirmPresenter: SignerConfirmPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func confirm() {
        guard let confirmationData = confirmationData else {
            return
        }

        let assetPrecision = chain.addressType.precision

        DataValidationRunner(validators: [
            dataValidatingFactory.has(fee: fee, locale: selectedLocale, onError: { [weak self] in
                self?.interactor.refreshFee()
            }),
            dataValidatingFactory.canPayFeeAndAmount(
                balance: balance,
                fee: fee,
                spendingAmount: Decimal.fromSubstrateAmount(confirmationData.amount ?? 0, precision: assetPrecision),
                locale: selectedLocale
            )
        ]).runValidation { [weak self] in
            self?.interactor.confirm()
        }
    }
}

extension SignerConfirmPresenter: SignerConfirmInteractorOutputProtocol {
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>) {
        switch result {
        case let .success(accountInfo):
            if let available = accountInfo?.data.available {
                balance = Decimal.fromSubstrateAmount(available, precision: chain.addressType.precision)
            }
        case let .failure(error):
            wireframe.presentErrorOrUndefined(error: error, from: view, locale: selectedLocale)
        }
    }

    func didExtractRequest(result: Result<SignerConfirmation, Error>) {
        switch result {
        case let .success(confirmationData):
            self.confirmationData = confirmationData
            provideCallViewModel()
            provideFeeViewModel()
        case let .failure(error):
            wireframe.presentErrorOrUndefined(error: error, from: view, locale: selectedLocale)
        }
    }

    func didReceivePrice(result: Result<PriceData?, Error>) {
        switch result {
        case let .success(priceData):
            self.priceData = priceData
            provideCallViewModel()
            provideFeeViewModel()
        case let .failure(error):
            wireframe.presentErrorOrUndefined(error: error, from: view, locale: selectedLocale)
        }
    }

    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>) {
        switch result {
        case let .success(runtimeDispatch):
            if let feeAmount = BigUInt(runtimeDispatch.fee) {
                fee = Decimal.fromSubstrateAmount(feeAmount, precision: chain.addressType.precision)
                provideFeeViewModel()
            }
        case let .failure(error):
            wireframe.presentErrorOrUndefined(error: error, from: view, locale: selectedLocale)
        }
    }

    func didReceiveSubmition(result: Result<Void, Error>) {
        switch result {
        case .success:
            wireframe.complete(on: view)
        case let .failure(error):
            wireframe.presentErrorOrUndefined(error: error, from: view, locale: selectedLocale)
        }
    }
}

extension SignerConfirmPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            provideCallViewModel()
            provideFeeViewModel()
        }
    }
}
