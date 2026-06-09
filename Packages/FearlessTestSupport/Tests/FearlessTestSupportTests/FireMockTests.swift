import XCTest
@testable import FearlessTestSupport

final class FireMockTests: XCTestCase {
    override func tearDown() {
        FireMock.enabled(false)
        FireMock.unregisterAll()
        super.tearDown()
    }

    func testEnabledTogglesMockInterception() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/fearless"))
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        FireMock.register(
            mock: FixtureMock(file: "firemock-response.json"),
            forURL: url,
            httpMethod: .get
        )

        FireMock.enabled(false)
        XCTAssertFalse(FireURLProtocol.canInit(with: request))

        FireMock.enabled(true)
        XCTAssertTrue(FireURLProtocol.canInit(with: request))
    }

    func testRegisteredMockReturnsFixtureDataAndStatusCode() async throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/fearless"))
        let session = makeSession()

        FireMock.enabled(true)
        FireMock.register(
            mock: FixtureMock(file: "firemock-response.json", statusCode: 201),
            forURL: url,
            httpMethod: .post
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let (data, response) = try await session.data(for: request)
        let httpResponse = try XCTUnwrap(response as? HTTPURLResponse)

        XCTAssertEqual(httpResponse.statusCode, 201)
        XCTAssertTrue(String(decoding: data, as: UTF8.self).contains("\"source\": \"firemock\""))
    }

    func testUnregisterAllRemovesRegisteredMocks() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/fearless"))
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        FireMock.enabled(true)
        FireMock.register(
            mock: FixtureMock(file: "firemock-response.json"),
            forURL: url,
            httpMethod: .delete
        )

        XCTAssertTrue(FireURLProtocol.canInit(with: request))

        FireMock.unregisterAll()

        XCTAssertFalse(FireURLProtocol.canInit(with: request))
    }

    private func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FireURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}

private struct FixtureMock: FireMockProtocol {
    let file: String
    var statusCode: Int = 200

    var bundle: Bundle { .module }

    func mockFile() -> String {
        file
    }
}
