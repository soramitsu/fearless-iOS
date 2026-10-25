import XCTest
@testable import fearless
import Cuckoo
import SSFRuntimeCodingService
import RobinHood

class RuntimePoolTests: XCTestCase {
    func testRuntimeProviderCreatedAndThenReused() {
        // given

        let factory = MockRuntimeProviderFactoryProtocol()

        let runtimePool = RuntimeProviderPool(runtimeProviderFactory: factory)

        let chain = ChainModelGenerator.generate(count: 1).first!

        final class CountingRuntimeProvider: RuntimeProviderProtocol {
            var setupCalls = 0
            var cleanupCalls = 0
            var runtimeSpecVersion: RuntimeSpecVersion = .defaultVersion
            var snapshot: RuntimeSnapshot?

            func setup() {
                setupCalls += 1
            }

            func setupHot() {}

            func cleanup() {
                cleanupCalls += 1
            }

            func readySnapshot() async throws -> RuntimeSnapshot {
                throw SSFRuntimeCodingService.RuntimeProviderError.providerUnavailable
            }

            func fetchCoderFactoryOperation() -> BaseOperation<RuntimeCoderFactoryProtocol> {
                BaseOperation()
            }

            func fetchCoderFactory() async throws -> RuntimeCoderFactoryProtocol {
                throw SSFRuntimeCodingService.RuntimeProviderError.providerUnavailable
            }
        }

        let expectedRuntimeProvider = CountingRuntimeProvider()

        // when
        stub(factory) { stub in
            stub.createRuntimeProvider(for: any(),
                                       chainTypes: any(),
                                       usedRuntimePaths: any()).thenReturn(expectedRuntimeProvider)
        }

        let newProvider = runtimePool.setupRuntimeProvider(for: chain, chainTypes: nil)
        let cachedProvider = runtimePool.setupRuntimeProvider(for: chain, chainTypes: nil)
        let fetchedProvider = runtimePool.getRuntimeProvider(for: chain.chainId)

        runtimePool.destroyRuntimeProvider(for: chain.chainId)

        let removedProvider = runtimePool.getRuntimeProvider(for: chain.chainId)

        // then

        XCTAssertTrue(expectedRuntimeProvider === newProvider)
        XCTAssertTrue(expectedRuntimeProvider === cachedProvider)
        XCTAssertTrue(expectedRuntimeProvider === fetchedProvider)
        XCTAssertNil(removedProvider)

        verify(factory, times(1)).createRuntimeProvider(for: any(), chainTypes: any(), usedRuntimePaths: any())
        XCTAssertEqual(expectedRuntimeProvider.setupCalls, 1)
        XCTAssertEqual(expectedRuntimeProvider.cleanupCalls, 1)
    }
}
