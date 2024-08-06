import Foundation

import SoraFoundation
import SSFModels

final class WalletTransactionDetailsPresenter {
    weak var view: WalletTransactionDetailsViewProtocol?
    let wireframe: WalletTransactionDetailsWireframeProtocol
    let interactor: WalletTransactionDetailsInteractorInputProtocol
    let viewModelFactory: WalletTransactionDetailsViewModelFactoryProtocol
    let chain: ChainModel

    private var viewModel: WalletTransactionDetailsViewModel?

    init(
        interactor: WalletTransactionDetailsInteractorInputProtocol,
        wireframe: WalletTransactionDetailsWireframeProtocol,
        viewModelFactory: WalletTransactionDetailsViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        chain: ChainModel
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.chain = chain
        self.localizationManager = localizationManager
    }
}

extension WalletTransactionDetailsPresenter: WalletTransactionDetailsPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func didTapCloseButton() {
        wireframe.close(view: view)
    }

    func didTapSenderView() {
        guard let view = view else {
            return
        }

        var address: String?

        if let viewModel = viewModel as? TransferTransactionDetailsViewModel {
            address = viewModel.from
        }

        if let viewModel = viewModel as? ExtrinsicTransactionDetailsViewModel {
            address = viewModel.sender
        }

        guard let address = address else {
            return
        }

        wireframe.presentAccountOptions(
            from: view,
            address: address,
            chain: chain,
            locale: selectedLocale
        )
    }

    func didTapReceiverOrValidatorView() {
        guard let view = view else {
            return
        }

        var address: String?

        if let viewModel = viewModel as? TransferTransactionDetailsViewModel {
            address = viewModel.to
        }

        if let viewModel = viewModel as? RewardTransactionDetailsViewModel {
            address = viewModel.validator
        }

        if let viewModel = viewModel as? SlashTransactionDetailsViewModel {
            address = viewModel.validator
        }

        guard let address = address else {
            return
        }

        wireframe.presentAccountOptions(
            from: view,
            address: address,
            chain: chain,
            locale: selectedLocale
        )
    }

    func didTapExtrinsicView() {
        if let viewModel = viewModel {
            wireframe.presentOptions(
                with: viewModel.extrinsicHash,
                locale: selectedLocale,
                chain: chain,
                from: view
            )
        }
    }
}

extension WalletTransactionDetailsPresenter: WalletTransactionDetailsInteractorOutputProtocol {
    func didReceiveTransaction(_ transaction: AssetTransactionData) {
        if let viewModel = viewModelFactory.buildViewModel(
            transaction: transaction,
            locale: selectedLocale,
            chain: chain
        ) {
            self.viewModel = viewModel
            view?.didReceiveState(.loaded(viewModel: viewModel))
        } else {
            viewModel = nil
            view?.didReceiveState(.empty)
        }
    }
}

extension WalletTransactionDetailsPresenter: Localizable {
    func applyLocalization() {}
}
