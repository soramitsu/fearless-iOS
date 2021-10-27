import UIKit

final class CrowdloanAgreementInteractor {
    weak var presenter: CrowdloanAgreementInteractorOutputProtocol!

    private let agreementService: CrowdloanAgreementServiceProtocol?

    init(agreementService: CrowdloanAgreementServiceProtocol?) {
        self.agreementService = agreementService
    }

    private func loadAgreementContents() {
        if let url = URL(
            string: "https://raw.githubusercontent.com/moonbeam-foundation/crowdloan-self-attestation/main/moonbeam/README.md"
        ) {
            do {
                // TODO: modify text by appending newlines and margin
                let contents = try String(contentsOf: url, encoding: .utf8)
                presenter.didReceiveAgreementText(result: .success(contents))
            } catch {
                presenter.didReceiveAgreementText(result: .failure(CrowdloanAgreementError.invalidAgreementContents))
            }
        } else {
            presenter.didReceiveAgreementText(result: .failure(CrowdloanAgreementError.invalidAgreementUrl))
        }
    }

    private func checkRemark() {
        agreementService?.checkRemark(with: { result in
            switch result {
            case let .success(verified):
                if verified {
                    self.presenter.didReceiveVerified(result: .success(verified))
                } else {
                    self.loadAgreementContents()
                }
            case let .failure(error):
                self.presenter.didReceiveVerified(result: .failure(error))
            }
        })
    }
}

extension CrowdloanAgreementInteractor: CrowdloanAgreementInteractorInputProtocol {
    func setup() {
        checkRemark()
    }
}
