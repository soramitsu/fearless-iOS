import Foundation

final class CrowdloanAgreementPresenter {
    weak var view: CrowdloanAgreementViewProtocol?
    let wireframe: CrowdloanAgreementWireframeProtocol
    let interactor: CrowdloanAgreementInteractorInputProtocol

    private var agreementTextResult: Result<String, Error>?
    private var isTermsAgreed: Bool = false
    private var paraId: ParaId
    private var crowdloanTitle: String

    init(
        interactor: CrowdloanAgreementInteractorInputProtocol,
        wireframe: CrowdloanAgreementWireframeProtocol,
        paraId: ParaId,
        crowdloanTitle: String
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.paraId = paraId
        self.crowdloanTitle = crowdloanTitle
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
            title: "Moonbeam Crowdloan Terms and Conditions",
            agreementText: text,
            isTermsAgreed: isTermsAgreed
        )

        view?.didReceive(state: .loaded(viewModel: viewModel))
    }
}

extension CrowdloanAgreementPresenter: CrowdloanAgreementPresenterProtocol {
    func confirmAgreement() {
        wireframe.showAgreementConfirm(
            from: view,
            paraId: paraId
        )
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
    func didReceiveAgreementText(result: Result<String, Error>) {
//        logger?.info("Did receive agreement text: \(result)")

        agreementTextResult = result
        updateView()
    }
}
