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
                try await service.refreshAccessTokenIfNeeded()
            } catch {
                DispatchQueue.main.async { [weak self] in
                    self?.output?.didReceive(error: error)
                }
                return
            }

            let response = await service.kycStatuses()
            switch response {
            case let .failure(error):
                DispatchQueue.main.async { [weak self] in
                    self?.output?.didReceive(error: error)
                }
            case let .success(statuses):
                switch await service.kycAttempts() {
                case let .failure(error):
                    self.output?.didReceive(error: error)
                case let .success(kycAttempts):
                    self.output?.didReceive(
                        status: statuses.sorted.last?.userStatus,
                        hasFreeAttempts: kycAttempts.hasFreeAttempts
                    )
                }
            }
        }
    }
}
