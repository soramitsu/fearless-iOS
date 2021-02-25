import Foundation
import RobinHood

final class DataProviderProxyTrigger: DataProviderTriggerProtocol {
    weak var delegate: DataProviderTriggerDelegate?

    func receive(event: DataProviderEvent) {}
}
