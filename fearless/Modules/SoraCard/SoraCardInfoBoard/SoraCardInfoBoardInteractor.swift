import UIKit

final class SoraCardInfoBoardInteractor {
    // MARK: - Private properties

    private weak var output: SoraCardInfoBoardInteractorOutput?
    private let service: SCKYCService
    let data: SCKYCUserDataModel

    init(data: SCKYCUserDataModel, service: SCKYCService) {
        self.data = data
        self.service = service
    }
}

// MARK: - SoraCardInfoBoardInteractorInput

extension SoraCardInfoBoardInteractor: SoraCardInfoBoardInteractorInput {
    func setup(with output: SoraCardInfoBoardInteractorOutput) {
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
                    self?.output?.didReceive(status: status)
                }
            }
        }
    }
}
