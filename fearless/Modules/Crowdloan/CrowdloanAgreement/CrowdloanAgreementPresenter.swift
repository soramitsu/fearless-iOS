import Foundation
import SwiftUI
import SoraFoundation
import RobinHood

final class CrowdloanAgreementPresenter {
    weak var view: CrowdloanAgreementViewProtocol?
    let wireframe: CrowdloanAgreementWireframeProtocol
    let interactor: CrowdloanAgreementInteractorInputProtocol

    private var agreementTextResult: Result<String, Error>?
    private var isTermsAgreed: Bool = false
    private var paraId: ParaId
    private var crowdloanTitle: String
    private var logger: LoggerProtocol
    private var customFlow: CustomCrowdloanFlow

    init(
        interactor: CrowdloanAgreementInteractorInputProtocol,
        wireframe: CrowdloanAgreementWireframeProtocol,
        paraId: ParaId,
        crowdloanTitle: String,
        logger: LoggerProtocol,
        customFlow: CustomCrowdloanFlow
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.paraId = paraId
        self.crowdloanTitle = crowdloanTitle
        self.logger = logger
        self.customFlow = customFlow
    }

    private func updateView() {
        guard let agreementTextResult = agreementTextResult else {
            view?.didReceive(state: .error)
            return
        }

        guard case let .success(text) = agreementTextResult else {
            view?.didReceive(state: .error)
            return
        }

        let viewModel = CrowdloanAgreementViewModel(
            title: crowdloanTitle,
            agreementText: text,
            isTermsAgreed: isTermsAgreed
        )

        view?.didReceive(state: .loaded(viewModel: viewModel))
    }

    private func proceedToConfirm(with _: String) {
        switch customFlow {
        case let .moonbeam(data):
            wireframe.showMoonbeamAgreementConfirm(
                from: view,
                paraId: paraId,
                moonbeamFlowData: data
            )
        default: break
        }
    }
}

extension CrowdloanAgreementPresenter: CrowdloanAgreementPresenterProtocol {
    func confirmAgreement() {
        interactor.agreeRemark()
    }

    func setTermsAgreed(value: Bool) {
        isTermsAgreed = value
        updateView()
    }

    func setup() {
        view?.didReceive(state: .loading)

        interactor.setup()
    }
}

extension CrowdloanAgreementPresenter: CrowdloanAgreementInteractorOutputProtocol {
    func didReceiveRemark(result: Result<MoonbeamAgreeRemarkData, Error>) {
        switch result {
        case let .success(remarkData):
            proceedToConfirm(with: remarkData.remark)
        case let .failure(error):
            wireframe.present(error: error, from: view, locale: selectedLocale)
        }
    }

    func didReceiveAgreementText(result: Result<String, Error>) {
        logger.info("Did receive agreement text: \(result)")

        switch result {
        case .success:
            agreementTextResult = result
            updateView()
        case let .failure(error):
            view?.didReceive(state: .error)
            wireframe.present(error: error, from: view, locale: selectedLocale)
        }
    }

    func didReceiveVerified(result: Result<Bool, Error>) {
        switch result {
        case let .success(verified):
            if verified {
                wireframe.presentContributionSetup(from: view, paraId: paraId)
            }
        case let .failure(error):
            logger.error(error.localizedDescription)
            wireframe.present(error: error, from: view, locale: selectedLocale)
        }
    }
}

extension CrowdloanAgreementPresenter: Localizable {
    func applyLocalization() {}
}
