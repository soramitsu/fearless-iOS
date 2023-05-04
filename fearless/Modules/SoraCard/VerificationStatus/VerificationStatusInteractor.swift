import Foundation
import PayWingsOAuthSDK

final class VerificationStatusInteractor {
    // MARK: - Private properties

    private weak var output: VerificationStatusInteractorOutput?
    private let service: SCKYCService
    private let data: SCKYCUserDataModel
    private let storage: SCStorage
    private let eventCenter: EventCenterProtocol
    private let tokenHolder: SCTokenHolderProtocol

    init(
        data: SCKYCUserDataModel,
        service: SCKYCService,
        storage: SCStorage,
        eventCenter: EventCenterProtocol,
        tokenHolder: SCTokenHolderProtocol
    ) {
        self.data = data
        self.service = service
        self.storage = storage
        self.eventCenter = eventCenter
        self.tokenHolder = tokenHolder
    }
}

// MARK: - VerificationStatusInteractorInput

extension VerificationStatusInteractor: VerificationStatusInteractorInput {
    func setup(with output: VerificationStatusInteractorOutput) {
        self.output = output
    }

    func getKYCStatus() {
        Task {
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
        await resetKYC()
        storage.set(isRetry: true)
    }

    func resetKYC() async {
        tokenHolder.removeToken()
        storage.set(isRetry: false)

        await MainActor.run {
            self.output?.resetKYC()
            self.eventCenter.notify(with: KYCShouldRestart(data: nil))
        }
    }

    func restartKYC() {
        storage.set(isRetry: true)
        output?.resetKYC()
        eventCenter.notify(with: KYCShouldRestart(data: data))
    }
}
