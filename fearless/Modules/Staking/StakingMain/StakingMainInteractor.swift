import Foundation
import SoraKeystore

final class StakingMainInteractor {
    weak var presenter: StakingMainInteractorOutputProtocol!

    private let settings: SettingsManagerProtocol
    private let eventCenter: EventCenterProtocol

    init(settings: SettingsManagerProtocol, eventCenter: EventCenterProtocol) {
        self.settings = settings
        self.eventCenter = eventCenter
    }

    private func updateSelectedAccount() {
        guard let address = settings.selectedAccount?.address else {
            return
        }

        presenter.didReceive(selectedAddress: address)
    }
}

extension StakingMainInteractor: StakingMainInteractorInputProtocol {
    func setup() {
        eventCenter.add(observer: self, dispatchIn: .main)

        updateSelectedAccount()
    }
}

extension StakingMainInteractor: EventVisitorProtocol {
    func processSelectedAccountChanged(event: SelectedAccountChanged) {
        updateSelectedAccount()
    }
}
