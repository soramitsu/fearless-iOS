import Foundation
import PayWingsOAuthSDK

final class VerificationStatusInteractor {
    // MARK: - Private properties

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

    func getKYCStatus() {
        Task {
            do {
                try await service.refreshAccessToken()
            } catch {
                DispatchQueue.main.async { [weak self] in
                    self?.output?.didReceive(error: error)
                }
                return
            }

            let response = await service.kycStatus()
            switch response {
            case let .failure(error):
                DispatchQueue.main.async { [weak self] in
                    self?.output?.didReceive(error: error)
                }
            case let .success(status):
                DispatchQueue.main.async { [weak self] in
                    self?.output?.didReceive(status: status.verificationStatus)
                }
            }
        }
    }
}
