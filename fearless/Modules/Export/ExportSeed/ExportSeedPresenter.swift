import Foundation
import SoraFoundation

final class ExportSeedPresenter {
    weak var view: ExportGenericViewProtocol?
    var wireframe: ExportSeedWireframeProtocol!
    var interactor: ExportSeedInteractorInputProtocol!

    let flow: ExportFlow
    let localizationManager: LocalizationManager

    private var valueForBackup: [String]?

    init(flow: ExportFlow, localizationManager: LocalizationManager) {
        self.flow = flow
        self.localizationManager = localizationManager
    }

    func didTapStringExport(_ value: String?) {
        guard let value = value else {
            return
        }

        let locale = localizationManager.selectedLocale

        let title = R.string.localizable.accountExportWarningTitle(preferredLanguages: locale.rLanguages)
        let message = R.string.localizable.accountExportWarningMessage(preferredLanguages: locale.rLanguages)

        let exportTitle = R.string.localizable.accountExportAction(preferredLanguages: locale.rLanguages)
        let exportAction = SheetAlertPresentableAction(title: exportTitle) { [weak self] in
            self?.share(value)
        }

        let cancelTitle = R.string.localizable.commonCancel(preferredLanguages: locale.rLanguages)
        let viewModel = SheetAlertPresentableViewModel(
            title: title,
            message: message,
            actions: [exportAction],
            closeAction: cancelTitle,
            icon: R.image.iconWarningBig()
        )

        wireframe.present(viewModel: viewModel, from: view)
    }

    func share(_ value: String) {
        wireframe.share(source: TextSharingSource(message: value), from: view) { [weak self] completed in
            if completed {
                self?.checkBackuped(for: value)
            }
        }
    }

    private func checkBackuped(for value: String) {
        valueForBackup?.removeAll(where: { $0 == value })
        guard valueForBackup.or([]).isEmpty else {
            return
        }
        interactor.seedDidBackuped(wallet: flow.wallet)
    }
}

extension ExportSeedPresenter: ExportGenericPresenterProtocol {
    func didLoadView() {
        let locale = localizationManager.selectedLocale

        let title = R.string.localizable.accountExportWarningTitle(preferredLanguages: locale.rLanguages)
        let message = R.string.localizable.accountExportWarningMessage(preferredLanguages: locale.rLanguages)

        let exportTitle = R.string.localizable.commonCancel(preferredLanguages: locale.rLanguages)
        let exportAction = SheetAlertPresentableAction(title: exportTitle) { [weak self] in
            self?.wireframe.back(view: self?.view)
        }

        let cancelTitle = R.string.localizable.commonProceed(preferredLanguages: locale.rLanguages)
        let cancelAction = SheetAlertPresentableAction(title: cancelTitle) {}
        let viewModel = SheetAlertPresentableViewModel(
            title: title,
            message: message,
            actions: [exportAction, cancelAction],
            closeAction: nil,
            icon: R.image.iconWarningBig()
        )

        wireframe.present(viewModel: viewModel, from: view)
    }

    func setup() {
        switch flow {
        case let .single(chain, address, wallet):
            interactor.fetchExportDataForAddress(address, chain: chain, wallet: wallet)
        case let .multiple(wallet, _):
            interactor.fetchExportDataForWallet(wallet, accounts: flow.exportingAccounts)
        }
    }
}

extension ExportSeedPresenter: ExportSeedInteractorOutputProtocol {
    func didReceive(exportData: [ExportSeedData]) {
        let viewModels = exportData.compactMap { seedData in
            ExportStringViewModel(
                option: .seed,
                chain: seedData.chain,
                cryptoType: seedData.chain.isEthereumBased ? nil : seedData.cryptoType,
                derivationPath: seedData.derivationPath,
                data: seedData.seed.toHex(includePrefix: true),
                ethereumBased: seedData.chain.isEthereumBased
            )
        }

        valueForBackup = viewModels.map { $0.data }

        let multipleExportViewModel = MultiExportViewModel(
            viewModels: viewModels,
            option: .seed,
            flow: flow
        )

        view?.set(viewModel: multipleExportViewModel)
    }

    func didReceive(error: Error) {
        if !wireframe.present(error: error, from: view, locale: localizationManager.selectedLocale) {
            _ = wireframe.present(
                error: CommonError.undefined,
                from: view,
                locale: localizationManager.selectedLocale
            )
        }
    }
}
