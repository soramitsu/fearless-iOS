import Foundation
import PayWingsOAuthSDK

final class VerificationStatusInteractor {
    // MARK: - Private properties

    private weak var output: VerificationStatusInteractorOutput?
    private let service: SCKYCService
    private let data: SCKYCUserDataModel
    private let storage: SCStorage
    private let eventCenter: EventCenterProtocol

    init(
        data: SCKYCUserDataModel,
        service: SCKYCService,
        storage: SCStorage,
        eventCenter: EventCenterProtocol
    ) {
        self.data = data
        self.service = service
        self.storage = storage
        self.eventCenter = eventCenter
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
                    DispatchQueue.main.async { [weak self] in
                        self?.output?.didReceive(error: error)
                    }
                case let .success(kycAttempts):
                    DispatchQueue.main.async { [weak self] in
                        self?.output?.didReceive(
                            status: statuses.sorted.last?.userStatus,
                            hasFreeAttempts: kycAttempts.hasFreeAttempts
                        )
                    }
                }
            }
        }
    }

    func retryKYC() async {
        storage.set(isRetry: true)
        await resetKYC()
    }

    func resetKYC() async {
        await storage.removeToken()
        storage.set(isRetry: false)

        await MainActor.run { [weak self] in
            self?.output?.resetKYC()
            self?.eventCenter.notify(with: KYCShouldRestart())
        }
    }
}
