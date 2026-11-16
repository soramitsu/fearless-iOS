import Foundation
import XCTest

@testable import fearless

final class CovDSigningServiceTests: XCTestCase {
    func testSigningServicesNeedASoraRuntimeAndALocalKey() {
        let wallet = CovDFixtures.wallet()
        let sora = CovDFixtures.soraChain(chainId: PolkamarktConstants.soraChainId)
        // Without a registered SORA runtime and a local signing key no mutation service can be built.
        XCTAssertNil(PolkamarktMutationService(wallet: wallet, chain: sora, capabilities: CovDPolkamarktMutationTests.complete))
        XCTAssertNil(PolkamarktMutationService(
            wallet: CovDFixtures.wallet(substrate: false), chain: sora, capabilities: CovDPolkamarktMutationTests.complete
        ))
        XCTAssertNil(DemeterMutationService(wallet: wallet, chain: sora, capabilities: CovDDemeterFixtures.complete))
        XCTAssertNil(DemeterMutationService(wallet: wallet, chain: CovDFixtures.soraChain(), capabilities: CovDDemeterFixtures.complete))
    }
}
