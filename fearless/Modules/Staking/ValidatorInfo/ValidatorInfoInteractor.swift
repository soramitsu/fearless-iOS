import Foundation
import RobinHood

final class ValidatorInfoInteractor {
    weak var presenter: ValidatorInfoInteractorOutputProtocol!
    private let priceProvider: AnySingleValueProvider<PriceData>

    private var validatorInfo: ValidatorInfoProtocol?

    init(
        validatorInfo: ValidatorInfoProtocol,
        priceProvider: AnySingleValueProvider<PriceData>
    ) {
        self.validatorInfo = validatorInfo
        self.priceProvider = priceProvider
    }

    private func subscribeToPriceChanges() {
        let updateClosure = { [weak self] (changes: [DataProviderChange<PriceData>]) in
            if changes.isEmpty {
                self?.presenter.didRecieve(priceData: nil)
            } else {
                for change in changes {
                    switch change {
                    case let .insert(item), let .update(item):
                        self?.presenter.didRecieve(priceData: item)
                    case .delete:
                        self?.presenter.didRecieve(priceData: nil)
                    }
                }
            }
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.presenter?.didReceive(priceError: error)
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
