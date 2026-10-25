import XCTest
@testable import Starscream

final class HandshakeSecurityTests: XCTestCase {
    // Public RFC6455 section1.3 handshake example; contains no credential.
    private let key = "dGhlIHNhbXBsZSBub25jZQ=="
    private let accept = "s3pPLMBiTxaQ9kYGzzhZRbK+xOo="

    func testRFCHandshakeAndCaseInsensitiveHTTPFields() {
        let verifier = FoundationSecurity()
        XCTAssertNil(verifier.validate(headers: ["Upgrade": "websocket", "Connection": "Upgrade", "Sec-WebSocket-Accept": accept], key: key))
        XCTAssertNil(verifier.validate(headers: ["upgrade": "WebSocket", "CONNECTION": "keep-alive, uPgRaDe", "sec-websocket-accept": " \(accept)\t"], key: key))
    }

    func testMissingMalformedDuplicateAndWrongAcceptCannotConnect() {
        let verifier = FoundationSecurity()
        let valid = ["Upgrade": "websocket", "Connection": "Upgrade", "Sec-WebSocket-Accept": accept]
        for name in valid.keys {
            var missing = valid; missing[name] = nil
            XCTAssertNotNil(verifier.validate(headers: missing, key: key))
            var empty = valid; empty[name] = ""
            XCTAssertNotNil(verifier.validate(headers: empty, key: key))
            var duplicate = valid; duplicate[name.lowercased()] = valid[name]
            XCTAssertNotNil(verifier.validate(headers: duplicate, key: key))
        }
        for invalid in ["wrong", accept.lowercased(), accept + "," + accept] {
            var headers = valid; headers["Sec-WebSocket-Accept"] = invalid
            XCTAssertNotNil(verifier.validate(headers: headers, key: key))
        }
        var wrongUpgrade = valid; wrongUpgrade["Upgrade"] = "h2c"
        XCTAssertNotNil(verifier.validate(headers: wrongUpgrade, key: key))
        var wrongConnection = valid; wrongConnection["Connection"] = "keep-alive"
        XCTAssertNotNil(verifier.validate(headers: wrongConnection, key: key))
        XCTAssertNotNil(verifier.validate(headers: valid, key: "different-client-nonce"))
    }
}
