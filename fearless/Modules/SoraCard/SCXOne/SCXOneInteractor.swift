import UIKit

final class SCXOneInteractor {
    // MARK: - Private properties

    private let service: SCKYCService
    private weak var output: SCXOneInteractorOutput?

    init(service: SCKYCService) {
        self.service = service
    }
}

// MARK: - SCXOneInteractorInput

extension SCXOneInteractor: SCXOneInteractorInput {
    func setup(with output: SCXOneInteractorOutput) {
        self.output = output
    }

    func checkStatus(paymentId: String) {
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task {
                let result = await self.service.xOneStatus(paymentId: paymentId)
                switch result {
                case let .failure(error):
                    print(error)
                case let .success(response):
                    if response.userStatus == .successful {
                    } else {
                        self.checkStatus(paymentId: paymentId)
                    }
                }
            }
        }
    }
}
