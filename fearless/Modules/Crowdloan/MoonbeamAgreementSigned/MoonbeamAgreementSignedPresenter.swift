import Foundation
import SwiftUI

final class MoonbeamAgreementSignedPresenter {
    weak var view: MoonbeamAgreementSignedViewProtocol?
    let wireframe: MoonbeamAgreementSignedWireframeProtocol
    let interactor: MoonbeamAgreementSignedInteractorInputProtocol

    private var extrinsicHash: String
    private var crowdloanName: String
    private var paraId: ParaId

    init(
        interactor: MoonbeamAgreementSignedInteractorInputProtocol,
        wireframe: MoonbeamAgreementSignedWireframeProtocol,
        extrinsicHash: String,
        paraId: ParaId,
        crowdloanName: String
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.extrinsicHash = extrinsicHash
        self.paraId = paraId
        self.crowdloanName = crowdloanName
    }
}

extension MoonbeamAgreementSignedPresenter: MoonbeamAgreementSignedPresenterProtocol {
    func actionContinue() {
        wireframe.presentContributionSetup(
            from: view,
            paraId: paraId
        )
    }

    func seeHash() {}

    func setup() {
        let viewModel = MoonbeamAgreementSignedViewModel(
            title: crowdloanName,
            hash: extrinsicHash
        )
        view?.didReceive(viewModel: viewModel)
    }
}

extension MoonbeamAgreementSignedPresenter: MoonbeamAgreementSignedInteractorOutputProtocol {}
