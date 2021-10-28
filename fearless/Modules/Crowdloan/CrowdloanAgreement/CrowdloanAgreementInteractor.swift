import UIKit

final class CrowdloanAgreementInteractor {
    weak var presenter: CrowdloanAgreementInteractorOutputProtocol!

    private let agreementService: CrowdloanAgreementServiceProtocol?
    private let signingWrapper: SigningWrapperProtocol
    private var agreementData: Data?
    private var customFlow: CustomCrowdloanFlow

    init(
        agreementService: CrowdloanAgreementServiceProtocol?,
        signingWrapper: SigningWrapperProtocol,
        customFlow: CustomCrowdloanFlow
    ) {
        self.agreementService = agreementService
        self.signingWrapper = signingWrapper
        self.customFlow = customFlow
    }

    private func loadAgreementContents() {
        switch customFlow {
        case let .moonbeam(moonbeamFlowData):
            guard
                let termsURL = URL(string: moonbeamFlowData.termsUrl)
            else {
                presenter.didReceiveAgreementText(result: .failure(CommonError.internal))
                return
            }

            agreementService?.fetchAgreementContent(from: termsURL, with: { [weak self] result in
                switch result {
                case let .success(agreementData):
                    self?.agreementData = agreementData

                    guard let agreementText = String(data: agreementData, encoding: .utf8) else {
                        self?.presenter.didReceiveAgreementText(result: .failure(CommonError.internal))
                        return
                    }

                    self?.presenter.didReceiveAgreementText(result: .success(agreementText))
                case let .failure(error):
                    self?.presenter.didReceiveAgreementText(result: .failure(CommonError.network))
                }
            })
        default: break
        }
    }

    private func checkRemark() {
        agreementService?.checkRemark(with: { [weak self] result in
            switch result {
            case let .success(verified):
                if verified {
                    self?.presenter.didReceiveVerified(result: .success(verified))
                } else {
                    self?.loadAgreementContents()
                }
            case let .failure(error):
                self?.presenter.didReceiveVerified(result: .failure(error))
            }
        })
    }
}

extension CrowdloanAgreementInteractor: CrowdloanAgreementInteractorInputProtocol {
    func setup() {
        checkRemark()
    }

    func agreeRemark() {
        guard let agreementData = agreementData else {
            assertionFailure("This method MUST be called only when there is attestation loaded")
            presenter.didReceiveRemark(result: .failure(CommonError.internal))
            return
        }

        agreementService?.agreeRemark(agreementData: agreementData, with: { [weak self] result in
            self?.presenter.didReceiveRemark(result: result)
        })
    }
}
