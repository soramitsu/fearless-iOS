#if canImport(Network)
import Foundation
import Network
import XCTest
@testable import Starscream

@available(macOS 10.14, iOS 12.0, *)
final class TCPAuthorizedWriteTests: XCTestCase {
    func testActualTCPHandoffRejectsDeniedBytesAndSendsExactApprovedBytes() throws {
        let pair = try Loopback(test: self)
        defer { pair.close() }
        let context = try XCTUnwrap(pair.transport.captureWriteContext())
        let denied = expectation(description: "denied")
        let deniedOperation = AuthorizedWrite(callbackQueue: .global()) { result in
            guard case .failure(let error) = result, error is Denied else { return XCTFail("expected denial") }
            denied.fulfill()
        }
        try pair.transport.write(data: Data("NEVER-SEND".utf8), context: context, operation: deniedOperation,
                                 authorization: TCPAuthority { _ in throw Denied() }) { _ in XCTFail("denied transport callback") }
        wait(for: [denied], timeout: 3)
        let approved = Data("exact-approved-transaction".utf8)
        let received = expectation(description: "only approved bytes")
        pair.peer.receive(minimumIncompleteLength: approved.count, maximumLength: 4096) { data, _, _, error in
            XCTAssertNil(error); XCTAssertEqual(data, approved); received.fulfill()
        }
        let completed = expectation(description: "OS accepted")
        let operation = AuthorizedWrite(callbackQueue: .global()) { result in
            if case .failure(let error) = result { XCTFail("unexpected \(error)") }
            completed.fulfill()
        }
        try pair.transport.write(data: approved, context: context, operation: operation, authorization: TCPAuthority()) { error in
            operation.complete(error.map { .failure($0) } ?? .success(()))
        }
        wait(for: [received, completed], timeout: 3)
    }

    func testDisconnectedTCPContextCannotAuthorizeOrWrite() throws {
        let pair = try Loopback(test: self)
        defer { pair.close() }
        let context = try XCTUnwrap(pair.transport.captureWriteContext())
        pair.transport.disconnect()
        XCTAssertNil(pair.transport.captureWriteContext())
        let operation = AuthorizedWrite(callbackQueue: .global()) { _ in }
        XCTAssertThrowsError(try pair.transport.write(data: Data([1]), context: context, operation: operation,
                                                      authorization: TCPAuthority { _ in XCTFail("stale authority") }) { _ in XCTFail("stale send") }) {
            XCTAssertEqual($0 as? AuthorizedWriteError, .connectionChanged)
        }
    }

    func testCancellationAfterActualTCPAcceptanceReportsUnknown() throws {
        let pair = try Loopback(test: self)
        defer { pair.close() }
        let context = try XCTUnwrap(pair.transport.captureWriteContext())
        let unknown = expectation(description: "accepted bytes cannot be recalled")
        let operation = AuthorizedWrite(callbackQueue: .global()) { result in
            guard case .failure(let error) = result else { return XCTFail("expected uncertainty") }
            XCTAssertEqual(error as? AuthorizedWriteError, .outcomeUnknown)
            unknown.fulfill()
        }
        // Deliberately hold completion pending while cancelling an accepted send.
        try pair.transport.write(data: Data([1, 2, 3]), context: context, operation: operation, authorization: TCPAuthority()) { _ in }
        operation.cancel()
        operation.complete(.success(()))
        wait(for: [unknown], timeout: 3)
    }
}

private struct Denied: Error {}
private final class TCPAuthority: WebSocketWriteAuthorizing {
    let action: (() throws -> Void) throws -> Void
    init(_ action: @escaping (() throws -> Void) throws -> Void = { try $0() }) { self.action = action }
    func authorize(_ handoff: () throws -> Void) throws { try action(handoff) }
}

@available(macOS 10.14, iOS 12.0, *)
private final class Loopback: TransportEventClient {
    let listener: NWListener
    let transport = TCPTransport()
    var peer: NWConnection!
    private let connected: XCTestExpectation
    private let queue = DispatchQueue(label: "test.fearless.loopback")
    init(test: XCTestCase) throws {
        connected = test.expectation(description: "client ready")
        listener = try NWListener(using: .tcp, on: .any)
        let listening = test.expectation(description: "listener ready")
        let accepted = test.expectation(description: "server accepted")
        listener.stateUpdateHandler = { state in
            if case .ready = state { listening.fulfill() }
            if case .failed(let error) = state { XCTFail("listener: \(error)") }
        }
        listener.newConnectionHandler = { [weak self] connection in
            guard let self = self else { return }
            self.peer = connection
            connection.start(queue: self.queue)
            accepted.fulfill()
        }
        listener.start(queue: queue)
        test.wait(for: [listening], timeout: 3)
        let port = try XCTUnwrap(listener.port)
        transport.register(delegate: self)
        transport.connect(url: try XCTUnwrap(URL(string: "ws://127.0.0.1:\(port.rawValue)")))
        test.wait(for: [connected, accepted], timeout: 3)
    }
    func connectionChanged(state: ConnectionState) {
        if case .connected = state { connected.fulfill() }
    }
    func close() {
        transport.disconnect()
        peer?.cancel()
        listener.cancel()
    }
}
#endif
