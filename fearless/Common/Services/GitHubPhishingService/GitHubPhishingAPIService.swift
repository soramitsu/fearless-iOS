import Foundation

class GitHubPhishingAPIService: ApplicationServiceProtocol {
    lazy var endPoint: String = { return "https://polkadot.js.org/phishing/address.json" }()

    let phishingAddressStorageManager: PhishingAddressRepositoryFacadeProtocol = PhishingAddressStorageManager()
    let logger = Logger.shared

    enum State {
        case throttled
        case active
        case inactive
    }

    private(set) var isThrottled: Bool = true
    private(set) var isActive: Bool = true

    func setup() {
        guard isThrottled else {
            return
        }

        isThrottled = false

        setupConnection()
    }

    func throttle() {
        guard !isThrottled else {
            return
        }

        isThrottled = true

        clearConnection()
    }

    private func setupConnection() {
        getDataWith { (result) in
            switch result {
            case .success(let data):
                self.processData(data: data)
            case .failure(let message):
                self.logger.error("Problem retreiving scam addresses: \(message)")
            }
        }
    }

    private func clearConnection() {

    }

    func getDataWith(completion: @escaping (Result<[String: AnyObject], Error>) -> Void) {
        guard let url = URL(string: endPoint) else { return }

        URLSession.shared.dataTask(with: url) { (data, _, error) in
            guard error == nil else { return }
            guard let data = data else { return }

            do {
                if let json = try JSONSerialization.jsonObject(with: data,
                                                               options: [.mutableContainers]) as? [String: AnyObject] {

                    DispatchQueue.main.async {
                        completion(.success(json))
                    }
                }
            } catch let error {
                completion(.failure(error))
            }
        }.resume()
    }

    private func processData(data: [String: AnyObject]) {
        self.phishingAddressStorageManager.updateRepository(from: data)
    }
}
