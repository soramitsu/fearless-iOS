import XCTest
@testable import fearless
import Cuckoo

class RuntimePoolTests: XCTestCase {
    func testRuntimeProviderCreatedAndThenReused() {
        // given

        let factory = MockRuntimeProviderFactoryProtocol()

        let runtimePool = RuntimeProviderPool(runtimeProviderFactory: factory)

        let chain = ChainModelGenerator.generate(count: 1).first!

        let expectedRuntimeProvider = MockRuntimeProviderProtocol()

        // when

        stub(expectedRuntimeProvider) { stub in
            stub.setup().thenDoNothing()
            stub.replaceTypesUsage(any()).thenDoNothing()
            stub.cleanup().thenDoNothing()
        }

        stub(factory) { stub in
            stub.createRuntimeProvider(for: any()).thenReturn(
                expectedRuntimeProvider,
                MockRuntimeProviderProtocol()
            )
        }

        let newProvider = runtimePool.setupRuntimeProvider(for: chain)
        let cachedProvider = runtimePool.setupRuntimeProvider(for: chain)
        let fetchedProvider = runtimePool.getRuntimeProvider(for: chain.chainId)

        runtimePool.destroyRuntimeProvider(for: chain.chainId)

        let removedProvider = runtimePool.getRuntimeProvider(for: chain.chainId)

        // then

        XCTAssertTrue(expectedRuntimeProvider === newProvider)
        XCTAssertTrue(expectedRuntimeProvider === cachedProvider)
        XCTAssertTrue(expectedRuntimeProvider === fetchedProvider)
        XCTAssertNil(removedProvider)

        verify(factory, times(1)).createRuntimeProvider(for: any())
        verify(expectedRuntimeProvider, times(1)).setup()
        verify(expectedRuntimeProvider, times(1)).replaceTypesUsage(any())
        verify(expectedRuntimeProvider, times(1)).cleanup()
    }
}
