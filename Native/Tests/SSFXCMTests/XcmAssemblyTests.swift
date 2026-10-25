import BigInt
import SSFExtrinsicKit
import XCTest

@testable import SSFXCM

final class XcmAssemblyTests: XCTestCase {
    func testReadOnlyServicesCannotBeTurnedIntoATransferService() {
        // act
        let services = XcmAssembly.createReadOnlyServices(
            chainId: "1",
            cryptoType: .ed25519,
            chainMetadata: nil,
            accountId: Data(repeating: 1, count: 32),
            chainType: .substrate,
            sourceConfig: XcmConfig.shared,
            chainRegistry: ChainRegistryProtocolMock()
        )

        // assert
        XCTAssertNil(services.extrinsic as? XcmExtrinsicServiceProtocol)
        XCTAssertNotNil(services.destinationFeeFetcher)
        XCTAssertNotNil(services.availableDestionationFetching)
    }

    func testReadOnlyServicesQuoteThroughTheirRegistryAndNeverSign() async {
        // arrange: a registry that knows no chain, so the quote fails before anything is built
        let registry = ChainRegistryProtocolMock()
        registry.getChainForClosure = { chainId in
            throw XcmError.convenience(error: "unknown chain \(chainId)")
        }
        let services = XcmAssembly.createReadOnlyServices(
            chainId: "1",
            cryptoType: .ed25519,
            chainMetadata: nil,
            accountId: Data(repeating: 1, count: 32),
            chainType: .substrate,
            sourceConfig: XcmConfig.shared,
            chainRegistry: registry
        )

        // act
        let result = await services.extrinsic.estimateOriginalFee(
            fromChainId: "1",
            assetSymbol: "XOR",
            destChainId: "2",
            destAccountId: Data(repeating: 2, count: 32),
            amount: 1
        )

        // assert
        guard case let .failure(error) = result else {
            return XCTFail("Expected the quote to fail on the unknown chain")
        }
        XCTAssertEqual(
            error.localizedDescription,
            XcmError.convenience(error: "unknown chain 1").localizedDescription
        )
        XCTAssertEqual(registry.getChainForCallsCount, 1)
    }
}
