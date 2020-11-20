import Foundation
import FearlessUtils

protocol KeystoreImportObserver: class {
    func didUpdateDefinition(from oldDefinition: KeystoreDefinition?)
}

protocol KeystoreImportServiceProtocol: URLHandlingServiceProtocol {
    var definition: KeystoreDefinition? { get }

    func add(observer: KeystoreImportObserver)

    func remove(observer: KeystoreImportObserver)

    func clear()
}

final class KeystoreImportService {
    private struct ObserverWrapper {
        weak var observer: KeystoreImportObserver?
    }

    private var observers: [ObserverWrapper] = []

    private(set) var definition: KeystoreDefinition?

    let logger: LoggerProtocol

    init(logger: LoggerProtocol) {
        self.logger = logger
    }
}

extension KeystoreImportService: KeystoreImportServiceProtocol {
    func handle(url: URL) -> Bool {
        do {
            let data = try Data(contentsOf: url)

            let oldDefinition = definition
            let definition = try JSONDecoder().decode(KeystoreDefinition.self, from: data)

            self.definition = definition

            observers.forEach { wrapper in
                wrapper.observer?.didUpdateDefinition(from: oldDefinition)
            }

            let address = definition.address ?? "no address"
            logger.debug("Imported keystore for address: \(address)")

            return true
        } catch {
            logger.warning("Error while parsing keystore from url: \(error)")
            return false
        }
    }

    func add(observer: KeystoreImportObserver) {
        observers = observers.filter { $0.observer !== nil}

        if observers.contains(where: { $0.observer === observer }) {
            return
        }

        let wrapper = ObserverWrapper(observer: observer)
        observers.append(wrapper)
    }

    func remove(observer: KeystoreImportObserver) {
        observers = observers.filter { $0.observer !== nil && observer !== observer}
    }

    func clear() {
        definition = nil
    }
}
