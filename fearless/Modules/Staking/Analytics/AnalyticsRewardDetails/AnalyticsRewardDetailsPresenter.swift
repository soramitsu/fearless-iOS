import Foundation
import UIKit.UIPasteboard
import SSFModels

final class AnalyticsRewardDetailsPresenter {
    weak var view: AnalyticsRewardDetailsViewProtocol?
    private let wireframe: AnalyticsRewardDetailsWireframeProtocol
    private let interactor: AnalyticsRewardDetailsInteractorInputProtocol
    private let viewModelFactory: AnalyticsRewardDetailsViewModelFactoryProtocol
    private let rewardModel: AnalyticsRewardDetailsModel
    private let chainAsset: ChainAsset

    init(
        rewardModel: AnalyticsRewardDetailsModel,
        interactor: AnalyticsRewardDetailsInteractorInputProtocol,
        wireframe: AnalyticsRewardDetailsWireframeProtocol,
        viewModelFactory: AnalyticsRewardDetailsViewModelFactoryProtocol,
        chainAsset: ChainAsset
    ) {
        self.rewardModel = rewardModel
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.chainAsset = chainAsset
    }

    private func copyEventId() {
        let eventId = rewardModel.eventId
        UIPasteboard.general.string = eventId

        let locale = view?.selectedLocale ?? .current
        let title = R.string.localizable.commonCopied(preferredLanguages: locale.rLanguages)
        wireframe.presentSuccessNotification(title, from: view)
    }

    private func createPolkascanAction(locale: Locale) -> SheetAlertPresentableAction? {
        guard let url = chainAsset.chain.polkascanAddressURL(rewardModel.eventId) else { return nil }
        let polkascanTitle = R.string.localizable
            .transactionDetailsViewPolkascan(preferredLanguages: locale.rLanguages)

        return SheetAlertPresentableAction(title: polkascanTitle) { [weak self] in
            if let view = self?.view {
                self?.wireframe.showWeb(url: url, from: view, style: .automatic)
            }
        }
    }

    private func createSubscanAction(locale: Locale) -> SheetAlertPresentableAction? {
        let blockNumber = String(rewardModel.eventId.prefix(while: { $0 != "-" }))
        guard let url = chainAsset.chain.subscanAddressURL(blockNumber) else { return nil }

        let subscanTitle = R.string.localizable
            .transactionDetailsViewSubscan(preferredLanguages: locale.rLanguages)
        return SheetAlertPresentableAction(title: subscanTitle) { [weak self] in
            if let view = self?.view {
                self?.wireframe.showWeb(url: url, from: view, style: .automatic)
            }
        }
    }

    private func createCopyAction(locale _: Locale) -> SheetAlertPresentableAction {
        let copyTitle = R.string.localizable
            .commonCopyId()
        return SheetAlertPresentableAction(title: copyTitle) { [weak self] in
            self?.copyEventId()
        }
    }
}

extension AnalyticsRewardDetailsPresenter: AnalyticsRewardDetailsPresenterProtocol {
    func setup() {
        let viewModel = viewModelFactory.createViweModel(rewardModel: rewardModel)
        view?.bind(viewModel: viewModel)
    }

    func handleEventIdAction() {
        let locale = view?.selectedLocale ?? .current
        let actions = [
            createCopyAction(locale: locale),
            createPolkascanAction(locale: locale),
            createSubscanAction(locale: locale)
        ].compactMap { $0 }

        let viewModel = SheetAlertPresentableViewModel(
            title: R.string.localizable.commonChooseAction(preferredLanguages: locale.rLanguages),
            message: nil,
            actions: actions,
            closeAction: R.string.localizable.commonCancel(preferredLanguages: locale.rLanguages),
            icon: R.image.iconWarningBig()
        )

        wireframe.present(
            viewModel: viewModel,
            from: view
        )
    }
}

extension AnalyticsRewardDetailsPresenter: AnalyticsRewardDetailsInteractorOutputProtocol {}
