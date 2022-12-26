import UIKit

final class VerificationStatusInteractor {
    // MARK: - Private properties

    var onStatus: ((SCVerificationStatus) -> Void)?
    var onError: ((String) -> Void)?
    var onClose: (() -> Void)?
    var onRestart: (() -> Void)?

    private weak var output: VerificationStatusInteractorOutput?
    private let service: SCKYCService
    private let data: SCKYCUserDataModel

    init(data: SCKYCUserDataModel, service: SCKYCService) {
        self.data = data
        self.service = service
    }
}

// MARK: - VerificationStatusInteractorInput

extension VerificationStatusInteractor: VerificationStatusInteractorInput {
    func setup(with output: VerificationStatusInteractorOutput) {
        self.output = output
    }

    func getKYCStatus() async {
        do {
            try await service.refreshAccessToken()
        } catch {
            output?.didReceive(error: error)
            return
        }
        let response = await service.kycStatus()
        switch response {
        case let .failure(error):
            output?.didReceive(error: error)
        case let .success(status):
            output?.didReceive(status: status.verificationStatus)
        }
    }
}
