import Foundation
import SwiftUI

final class CrowdloanAgreementSignedPresenter {
    weak var view: CrowdloanAgreementSignedViewProtocol?
    let wireframe: CrowdloanAgreementSignedWireframeProtocol
    let interactor: CrowdloanAgreementSignedInteractorInputProtocol

    private var extrinsicHash: String
    private var paraId: ParaId
    private var customFlow: CustomCrowdloanFlow

    init(
        interactor: CrowdloanAgreementSignedInteractorInputProtocol,
        wireframe: CrowdloanAgreementSignedWireframeProtocol,
        extrinsicHash: String,
        paraId: ParaId,
        customFlow: CustomCrowdloanFlow
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.extrinsicHash = extrinsicHash
        self.paraId = paraId
        self.customFlow = customFlow
    }
}

extension CrowdloanAgreementSignedPresenter: CrowdloanAgreementSignedPresenterProtocol {
    func actionContinue() {
        wireframe.presentContributionSetup(
            from: view,
            paraId: paraId,
            customFlow: customFlow
        )
    }

    func seeHash() {
        guard let url = URL(string: "https://polkadot.subscan.io/transaction/\(extrinsicHash)") else { return }

        guard let view = view else { return }

        wireframe.showWeb(
            url: url,
            from: view,
            style: .modal
        )
    }

    func setup() {
        let viewModel = CrowdloanAgreementSignedViewModel(
            title: customFlow.name,
            hash: extrinsicHash
        )
        view?.didReceive(viewModel: viewModel)
    }
}

extension CrowdloanAgreementSignedPresenter: CrowdloanAgreementSignedInteractorOutputProtocol {}
