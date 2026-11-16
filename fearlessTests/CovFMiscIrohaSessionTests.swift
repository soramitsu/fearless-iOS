import XCTest
@testable import fearless

final class CovFMiscIrohaSessionTests: XCTestCase {
    private let walletURI = "irohaconnect://connect?" +
        "sid=yjnfVXnZeSYGYZRtmaP7falZC6w04-qu9eQ-9dBsDvQ&" +
        "network_id=hash%3A82531CE8EAE8BFF6BEECA4698BFD13A3BC8BEC5F0EE0D23D428C97FC17AB0F3B%233E94&" +
        "app_pk=ew1H2TQn-DERYHgcfHM_2J-IlwrvSQ2KoO4ZpMuKGxQ&" +
        "nonce=EREREREREREREREREREREQ&v=1&role=wallet&" +
        "node=https%3A%2F%2Ftaira.sora.org&" +
        "token=IiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiI&" +
        "relay=REREREREREREREREREREREREREREREREREREREREREQ"

    func testErrorsDescribeEveryFailureDistinctly() {
        let errors: [IrohaConnectSessionServiceError] = [
            .transportUnavailable, .authenticationFailed, .connectTimedOut, .requestTimedOut, .unexpectedMessage, .sessionExpired
        ]
        let descriptions = errors.compactMap(\.errorDescription)
        XCTAssertEqual(descriptions.count, errors.count)
        XCTAssertEqual(Set(descriptions).count, errors.count)
        XCTAssertTrue(descriptions.allSatisfy { !$0.isEmpty })
    }

    func testApprovalsWithoutAnOpenRequestCloseWithAccountMismatchOnce() throws {
        for signature in [false, true] {
            let fixture = try makeSession()
            let closed = expectation(description: "closed")
            fixture.delegate.onClose = { closed.fulfill() }
            let account = IrohaConnectAccountDescriptor(walletName: "W", accountID: "acc", publicKey: Data(repeating: 1, count: 32))
            if signature {
                fixture.session.approveSignature(for: account)
            } else {
                fixture.session.approveConnection(for: account)
            }
            wait(for: [closed], timeout: 5)
            XCTAssertEqual(fixture.delegate.closeErrors.count, 1)
            XCTAssertEqual(fixture.delegate.closeErrors.first as? IrohaConnectAccountProviderError, .accountMismatch)
            fixture.session.close()
            RunLoop.main.run(until: Date().addingTimeInterval(0.1))
            XCTAssertEqual(fixture.delegate.closeErrors.count, 1)
            XCTAssertEqual(fixture.provider.signedMessages, 0)
        }
    }

    func testCloseReportsCleanShutdown() throws {
        let fixture = try makeSession()
        let closed = expectation(description: "closed")
        fixture.delegate.onClose = { closed.fulfill() }
        fixture.session.close()
        wait(for: [closed], timeout: 5)
        XCTAssertEqual(fixture.delegate.closeErrors.count, 1)
        XCTAssertNil(fixture.delegate.closeErrors.first ?? nil)
    }

    func testRelayOpeningWithWrongSubprotocolFailsAuthentication() throws {
        let fixture = try makeSession()
        let closed = expectation(description: "closed")
        fixture.delegate.onClose = { closed.fulfill() }
        let (urlSession, task) = try unstartedSocket()
        fixture.session.urlSession(urlSession, webSocketTask: task, didOpenWithProtocol: "other")
        wait(for: [closed], timeout: 5)
        XCTAssertEqual(fixture.delegate.closeErrors.first as? IrohaConnectSessionServiceError, .authenticationFailed)
        urlSession.invalidateAndCancel()
    }

    func testOpenedThenClosedRelayReportsTransportLoss() throws {
        let fixture = try makeSession()
        let closed = expectation(description: "closed")
        fixture.delegate.onClose = { closed.fulfill() }
        let (urlSession, task) = try unstartedSocket()
        fixture.session.urlSession(urlSession, webSocketTask: task, didOpenWithProtocol: fixture.session.handoff.webSocketSubprotocol)
        fixture.session.urlSession(urlSession, webSocketTask: task, didCloseWith: .goingAway, reason: nil)
        wait(for: [closed], timeout: 5)
        XCTAssertEqual(fixture.delegate.closeErrors.first as? IrohaConnectSessionServiceError, .transportUnavailable)
        fixture.session.urlSession(urlSession, webSocketTask: task, didCloseWith: .goingAway, reason: nil)
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        XCTAssertEqual(fixture.delegate.closeErrors.count, 1)
        urlSession.invalidateAndCancel()
    }

    private func makeSession() throws -> (session: IrohaConnectSessionService, delegate: CovFMiscIrohaDelegate, provider: CovFMiscIrohaProvider) {
        let provider = CovFMiscIrohaProvider()
        let session = try IrohaConnectSessionService(handoff: IrohaConnectWalletURI.parse(walletURI), accountProvider: provider)
        let delegate = CovFMiscIrohaDelegate()
        session.delegate = delegate
        return (session, delegate, provider)
    }

    private func unstartedSocket() throws -> (URLSession, URLSessionWebSocketTask) {
        let urlSession = URLSession(configuration: .ephemeral)
        return (urlSession, urlSession.webSocketTask(with: try XCTUnwrap(URL(string: "wss://relay.covf.invalid/ws"))))
    }
}

final class CovFMiscIrohaProvider: IrohaConnectAccountProviding {
    private(set) var signedMessages = 0

    func selectedAccount() throws -> IrohaConnectAccountDescriptor {
        IrohaConnectAccountDescriptor(walletName: "W", accountID: "acc", publicKey: Data(repeating: 1, count: 32))
    }

    func sign(_ message: Data, for _: IrohaConnectAccountDescriptor) throws -> Data {
        signedMessages += 1
        return message
    }
}

final class CovFMiscIrohaDelegate: IrohaConnectSessionServiceDelegate {
    private(set) var closeErrors: [Error?] = []
    var onClose: (() -> Void)?

    func irohaConnectSession(_: IrohaConnectSessionService, requestsConnection _: IrohaConnectOpenFrame, account _: IrohaConnectAccountDescriptor) {}
    func irohaConnectSessionDidApprove(_: IrohaConnectSessionService) {}
    func irohaConnectSession(_: IrohaConnectSessionService, requestsSignature _: IrohaConnectSignRawRequest, account _: IrohaConnectAccountDescriptor) {}
    func irohaConnectSessionDidCompleteSignature(_: IrohaConnectSessionService) {}

    func irohaConnectSession(_: IrohaConnectSessionService, didCloseWith error: Error?) {
        closeErrors.append(error)
        onClose?()
    }
}
