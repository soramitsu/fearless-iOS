import UIKit

final class PurchaseInteractor {
    weak var presenter: PurchaseInteractorOutputProtocol!

    let eventCenter: EventCenterProtocol

    init(eventCenter: EventCenterProtocol) {
        self.eventCenter = eventCenter
    }
}

extension PurchaseInteractor: PurchaseInteractorInputProtocol {
    func setup() {
        eventCenter.add(observer: self, dispatchIn: .main)
    }
}

extension PurchaseInteractor: EventVisitorProtocol {
    func processPurchaseCompletion(event: PurchaseCompleted) {
        presenter.didCompletePurchase()
    }
}
