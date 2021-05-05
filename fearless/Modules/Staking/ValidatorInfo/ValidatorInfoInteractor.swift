import Foundation
import RobinHood

final class ValidatorInfoInteractor {
    weak var presenter: ValidatorInfoInteractorOutputProtocol!
    private let priceProvider: AnySingleValueProvider<PriceData>

    private let validatorInfo: ValidatorInfoProtocol?

    init(
        validatorInfo: ValidatorInfoProtocol,
        priceProvider: AnySingleValueProvider<PriceData>
    ) {
        self.validatorInfo = validatorInfo
        self.priceProvider = priceProvider
    }

    private func subscribeToPriceChanges() {
        let updateClosure = { [weak self] (changes: [DataProviderChange<PriceData>]) in
            guard !changes.isEmpty else {
                self?.presenter.didRecieve(priceData: nil)
                return
            }

            let priceData = changes.reduceToLastChange()
            self?.presenter.didRecieve(priceData: priceData)
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.presenter?.didReceive(priceError: error)
            return
        }

        let options = DataProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false
        )

        priceProvider.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )
    }
}

extension ValidatorInfoInteractor: ValidatorInfoInteractorInputProtocol {
    func setup() {
        subscribeToPriceChanges()

        guard let validatorInfo = validatorInfo else { return }
        presenter?.didReceive(validatorInfo: validatorInfo)
    }
}
