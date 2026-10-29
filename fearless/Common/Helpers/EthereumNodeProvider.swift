import Foundation
import Web3

/// Why an EVM node could not be used for its network.
enum EthereumNodeError: LocalizedError, Equatable {
    /// The node reported another network's chain id.
    case wrongNetwork(expected: BigUInt, reported: BigUInt)
    /// The node's reply to `eth_chainId` was not a chain id.
    case unreadableChainId
    /// The node did not answer a read in time.
    case timeout

    var errorDescription: String? {
        switch self {
        case .wrongNetwork:
            return "The node serves another network. Select another node in network settings."
        case .unreadableChainId:
            return "The node did not report which network it serves."
        case .timeout:
            return "The node did not answer in time."
        }
    }
}

/// Sends a network's EVM requests to one node, and only once the node has reported the network's chain id
/// (`eth_chainId`, asked once). A node serving another network fails every request with
/// `EthereumNodeError.wrongNetwork`, so its balances, fees and nonces are never taken for this network's.
/// Requests made while the node is being asked wait for its answer.
class EthereumNodeProvider: Web3Provider {
    let url: URL

    private let transport: Web3Provider
    private let expectedChainId: BigUInt?
    private let lock = NSLock()
    private var check: ChainIdCheck = .notAsked
    private var askNumber = 0
    private var waiting: [(Error?) -> Void] = []

    private enum ChainIdCheck {
        case notAsked
        case asking
        case matched
        case failed(EthereumNodeError)
    }

    /// - Parameter expectedChainId: the catalog's chain id; with none, requests are sent unchecked.
    init(url: URL, transport: Web3Provider, expectedChainId: BigUInt?) {
        self.url = url
        self.transport = transport
        self.expectedChainId = expectedChainId
    }

    func send<Params, Result>(request: RPCRequest<Params>, response: @escaping Web3ResponseCompletion<Result>) {
        whenNetworkConfirmed { [transport] error in
            if let error {
                response(Web3Response(error: error))
            } else {
                transport.send(request: request, response: response)
            }
        }
    }

    /// Runs `body` once the node has reported the expected chain id, or with the reason it has not.
    func whenNetworkConfirmed(_ body: @escaping (Error?) -> Void) {
        guard let expectedChainId else {
            body(nil)
            return
        }

        lock.lock()
        switch check {
        case .matched:
            lock.unlock()
            body(nil)
        case let .failed(error):
            lock.unlock()
            body(error)
        case .asking:
            waiting.append(body)
            lock.unlock()
        case .notAsked:
            check = .asking
            askNumber += 1
            let number = askNumber
            waiting.append(body)
            lock.unlock()
            askChainId(number: number, expected: expectedChainId)
        }
    }

    /// A chain id as the catalog or a node writes it: hexadecimal with `0x`, or decimal.
    static func chainId(fromCatalogId value: String) -> BigUInt? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().hasPrefix("0x") {
            let digits = trimmed.dropFirst(2)
            return digits.isEmpty ? nil : BigUInt(digits, radix: 16)
        }
        return trimmed.isEmpty ? nil : BigUInt(trimmed, radix: 10)
    }

    private func askChainId(number: Int, expected: BigUInt) {
        let request = BasicRPCRequest(id: 1, jsonrpc: Web3.jsonrpc, method: "eth_chainId", params: [])
        // The node is kept until it answers: the requests waiting here must all be answered.
        transport.send(request: request) { (response: Web3Response<String>) in
            self.finishCheck(number: number, response: response, expected: expected)
        }
    }

    private func finishCheck(number: Int, response: Web3Response<String>, expected: BigUInt) {
        let outcome: ChainIdCheck
        let error: Error?

        switch response.status {
        case let .success(value):
            if let reported = Self.chainId(fromCatalogId: value) {
                if reported == expected {
                    outcome = .matched
                    error = nil
                } else {
                    let mismatch = EthereumNodeError.wrongNetwork(expected: expected, reported: reported)
                    outcome = .failed(mismatch)
                    error = mismatch
                }
            } else {
                outcome = .failed(.unreadableChainId)
                error = EthereumNodeError.unreadableChainId
            }
        case let .failure(failure):
            // No answer says nothing about the network, so the next request asks again.
            outcome = .notAsked
            error = failure
        }

        lock.lock()
        // A transport may answer one request twice (a failed socket write, then its timeout).
        guard case .asking = check, number == askNumber else {
            lock.unlock()
            return
        }
        check = outcome
        let bodies = waiting
        waiting = []
        lock.unlock()

        bodies.forEach { $0(error) }
    }
}

/// `EthereumNodeProvider` for a WebSocket node, which also takes subscriptions.
final class EthereumBidirectionalNodeProvider: EthereumNodeProvider, Web3BidirectionalProvider {
    private let socket: Web3BidirectionalProvider

    init(url: URL, transport: Web3BidirectionalProvider, expectedChainId: BigUInt?) {
        socket = transport
        super.init(url: url, transport: transport, expectedChainId: expectedChainId)
    }

    func subscribe<Params, Result>(
        request: RPCRequest<Params>,
        response: @escaping Web3ResponseCompletion<String>,
        onEvent: @escaping Web3ResponseCompletion<Result>
    ) {
        whenNetworkConfirmed { [socket] error in
            if let error {
                response(Web3Response(error: error))
            } else {
                socket.subscribe(request: request, response: response, onEvent: onEvent)
            }
        }
    }

    func unsubscribe(subscriptionId: String, completion: @escaping (_ success: Bool) -> Void) {
        socket.unsubscribe(subscriptionId: subscriptionId, completion: completion)
    }
}

/// Whether a failed EVM read says the node is unusable rather than answering for the chain: no connection, an HTTP
/// error, a reply that is not JSON-RPC, a JSON-RPC error, no answer in time, or another network. A reverted or
/// undecodable call is the chain's answer about that contract, and every other node would give it too.
enum EthereumNodeFailure {
    static func isNodeFailure(_ error: Error) -> Bool {
        switch error {
        case is EthereumNodeError:
            return true
        case let rpcError as EthereumRPCErrorObject:
            return !rpcError.isRevert
        case is EthereumTransportFailure:
            return true
        default:
            return false
        }
    }
}

/// A request that failed on its way to or from the node (`Web3Response.Error`): refused, an HTTP error status,
/// a dropped socket, a reply that is not JSON-RPC.
protocol EthereumTransportFailure: Error {}

extension Web3Response.Error: EthereumTransportFailure {}

/// A JSON-RPC error object a node answered with.
protocol EthereumRPCErrorObject: Error {
    var rpcCode: Int { get }
    var rpcMessage: String { get }
}

extension EthereumRPCErrorObject {
    /// EIP-1474's code 3, or the "execution reverted" message Geth, Erigon and Besu answer with.
    var isRevert: Bool {
        rpcCode == 3 || rpcMessage.range(of: "revert", options: .caseInsensitive) != nil
    }
}

extension RPCResponse.Error: EthereumRPCErrorObject {
    var rpcCode: Int { code }
    var rpcMessage: String { message }
}
