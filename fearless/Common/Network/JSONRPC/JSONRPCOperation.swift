import Foundation
import RobinHood

enum JSONRPCOperationError: Error {
    case timeout
}

final class JSONRPCOperation<T: ScaleDecodable>: BaseOperation<T> {
    let engine: JSONRPCEngine
    private(set) var requestId: UInt16?
    let method: String
    let parameters: [String]
    let timeout: Int

    init(engine: JSONRPCEngine, method: String, parameters: [String], timeout: Int = 60) {
        self.engine = engine
        self.method = method
        self.parameters = parameters
        self.timeout = timeout

        super.init()
    }

    override func main() {
        super.main()

        if isCancelled {
            return
        }

        if result != nil {
            return
        }

        do {
            let semaphore = DispatchSemaphore(value: 0)

            var optionalCallResult: Result<String, Error>?

            requestId = try engine.callMethod(method, params: parameters) { result in
                optionalCallResult = result

                semaphore.signal()
            }

            let status = semaphore.wait(timeout: .now() + .seconds(timeout))

            if status == .timedOut {
                result = .failure(JSONRPCOperationError.timeout)
                return
            }

            guard let callResult = optionalCallResult else {
                return
            }

            switch callResult {
            case .success(let response):
                let data = try Data(hexString: response)
                let resultObject = try T.init(scaleDecoder: ScaleDecoder(data: data))
                result = .success(resultObject)
            case .failure(let error):
                result = .failure(error)
            }

        } catch {
            result = .failure(error)
        }
    }

    override func cancel() {
        if let requestId = requestId {
            engine.cancelForIdentifier(requestId)
        }

        super.cancel()
    }
}
