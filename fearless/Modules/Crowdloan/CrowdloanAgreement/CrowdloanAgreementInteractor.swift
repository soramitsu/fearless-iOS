import UIKit

final class CrowdloanAgreementInteractor {
    weak var presenter: CrowdloanAgreementInteractorOutputProtocol!

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
}

extension CrowdloanAgreementInteractor: CrowdloanAgreementInteractorInputProtocol {
    func setup() {
        loadAgreementContents()
    }
}
