import XCTest
@testable import fearless
import RobinHood

class RuntimeFilesOperationFacadeTests: XCTestCase {

    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("test")

    private func clean() {
        try? FileManager.default.removeItem(at: directory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func testInitialWestendDefault() {
        performInitialDefaultFetchTest(chain: .westend)
    }

    func testInitialWestendNetwork() {
        performInitialNetworkFetchTest(chain: .westend)
    }

    func testInitialKusamaDefault() {
        performInitialDefaultFetchTest(chain: .kusama)
    }

    func testInitialKusamaNetwork() {
        performInitialNetworkFetchTest(chain: .kusama)
    }

    func testInitialPolkadotDefault() {
        performInitialDefaultFetchTest(chain: .polkadot)
    }

    func testInitiaPolkadotNetwork() {
        performInitialNetworkFetchTest(chain: .polkadot)
    }

    func testWriteReadWestendDefault() {
        performWriteReadDefaultTest(chain: .westend)
    }

    func testWriteReadWestendNetwork() {
        performWriteReadDefaultTest(chain: .westend)
    }

    func testWriteReadKusamaDefault() {
        performWriteReadDefaultTest(chain: .kusama)
    }

    func testWriteReadKusamaNetwork() {
        performWriteReadNetworkTest(chain: .kusama)
    }

    func testWriteReadPolkadotDefault() {
        performWriteReadDefaultTest(chain: .polkadot)
    }

    func testWriteReadPolkadotNetwork() {
        performWriteReadDefaultTest(chain: .polkadot)
    }

    // MARK: Private

    private func performInitialDefaultFetchTest(chain: Chain) {
        // given

        let facade = RuntimeFilesOperationFacade(repository: FileRepository(),
                                                 directoryPath: directory.path)
        let queue = OperationQueue()

        // when

        let wrapper = facade.fetchDefaultOperation(for: chain)
        queue.addOperations(wrapper.allOperations, waitUntilFinished: true)

        // then

        do {
            let data = try wrapper.targetOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
            XCTAssertNotNil(data)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private func performInitialNetworkFetchTest(chain: Chain) {
        // given

        let facade = RuntimeFilesOperationFacade(repository: FileRepository(),
                                                 directoryPath: directory.path)
        let queue = OperationQueue()

        // when

        let wrapper = facade.fetchNetworkOperation(for: chain)
        queue.addOperations(wrapper.allOperations, waitUntilFinished: true)

        // then

        do {
            let data = try wrapper.targetOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
            XCTAssertNotNil(data)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private func performWriteReadDefaultTest(chain: Chain) {
        // given

        let expectedData = "Fearless default".data(using: .utf8)!
        let facade = RuntimeFilesOperationFacade(repository: FileRepository(),
                                                 directoryPath: directory.path)
        let queue = OperationQueue()

        // when

        let saveWrapper = facade.saveDefaultOperation(for: chain, data: { expectedData })
        let readWrapper = facade.fetchDefaultOperation(for: chain)

        readWrapper.allOperations.forEach { readOperation in
            saveWrapper.allOperations.forEach { readOperation.addDependency($0) }
        }

        queue.addOperations(saveWrapper.allOperations + readWrapper.allOperations,
                            waitUntilFinished: true)

        // then

        do {
            let resultData = try readWrapper.targetOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

            XCTAssertEqual(resultData, expectedData)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private func performWriteReadNetworkTest(chain: Chain) {
        // given

        let expectedData = "Fearless network".data(using: .utf8)!
        let facade = RuntimeFilesOperationFacade(repository: FileRepository(),
                                                 directoryPath: directory.path)
        let queue = OperationQueue()

        // when

        let saveWrapper = facade.saveNetworkOperation(for: chain, data: { expectedData })
        let readWrapper = facade.fetchNetworkOperation(for: chain)

        readWrapper.allOperations.forEach { readOperation in
            saveWrapper.allOperations.forEach { readOperation.addDependency($0) }
        }

        queue.addOperations(saveWrapper.allOperations + readWrapper.allOperations,
                            waitUntilFinished: true)

        // then

        do {
            let resultData = try readWrapper.targetOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

            XCTAssertEqual(resultData, expectedData)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

}
