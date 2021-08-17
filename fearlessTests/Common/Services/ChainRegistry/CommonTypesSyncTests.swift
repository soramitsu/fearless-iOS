import XCTest
@testable import fearless
import Cuckoo
import RobinHood
import FearlessUtils

class CommonTypesSyncTests: XCTestCase {
    func testSyncSuccessfullyCompletes() {
        performSyncSuccessfullyCompletes(after: 0)
    }

    func testRetryTriggersIfSyncAttemptFails() {
        performSyncSuccessfullyCompletes(after: 2)
    }

    private func performSyncSuccessfullyCompletes(after expectedFailuresCount: Int) {
        do {
            // given

            let filesOperationFactory = MockRuntimeFilesOperationFactoryProtocol()
            let dataOperationFactory = MockDataOperationFactoryProtocol()
            let eventCenter = MockEventCenterProtocol()
            let operationQueue = OperationQueue()

            let commonTypesService = CommonTypesSyncService(
                url: URL(string: "https://google.com")!,
                filesOperationFactory: filesOperationFactory,
                dataOperationFactory: dataOperationFactory,
                eventCenter: eventCenter,
                operationQueue: operationQueue
            )

            // when

            let fileSavedExpectation = XCTestExpectation()
            let dataFetchedExpectation = XCTestExpectation()
            let eventDeliveredExpectation = XCTestExpectation()

            let expectedFileData = Data.random(of: 1024)!
            let expectedHash = try StorageHasher.twox256.hash(data: expectedFileData).toHex()

            var currentFailuresCount: Int = 0

            stub(filesOperationFactory) { stub in
                stub.saveCommonTypesOperation(data: any()).then { dataClosure in
                    let saveOperation = ClosureOperation<Void> {
                        do {
                            let actualData = try dataClosure()
                            XCTAssertEqual(expectedFileData, actualData)
                            fileSavedExpectation.fulfill()
                        } catch {
                            if currentFailuresCount > expectedFailuresCount {
                                XCTFail("Unexpected error: \(error)")
                            }
                        }
                    }

                    return CompoundOperationWrapper(targetOperation: saveOperation)
                }
            }

            stub(dataOperationFactory) { stub in
                stub.fetchData(from: any()).then { _ in
                    if currentFailuresCount == expectedFailuresCount {
                        return ClosureOperation {
                            dataFetchedExpectation.fulfill()
                            return expectedFileData
                        }
                    } else {
                        currentFailuresCount += 1

                        return BaseOperation.createWithError(BaseOperationError.unexpectedDependentResult)
                    }
                }
            }

            stub(eventCenter) { stub in
                stub.notify(with: any()).then { event in
                    if let syncEvent = event as? RuntimeCommonTypesSyncCompleted {
                        XCTAssertEqual(expectedHash, syncEvent.fileHash)
                        eventDeliveredExpectation.fulfill()
                    }
                }
            }

            commonTypesService.syncUp()

            // then

            wait(
                for: [dataFetchedExpectation, fileSavedExpectation, eventDeliveredExpectation],
                timeout: 10,
                enforceOrder: true
            )

        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
