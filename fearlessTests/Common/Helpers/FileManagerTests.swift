import XCTest
@testable import fearless
import RobinHood

class FileManagerTests: XCTestCase {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("test")

    private func clean() {
        try? FileManager.default.removeItem(at: directory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func setUp() {
        clean()
    }

    override func tearDown() {
        clean()
    }

    func testNonExistingFile() throws {
        // given

        let filesRepository = FileRepository()
        let filePath = directory.appendingPathComponent("test").path
        let queue = OperationQueue()

        // when

        let operation = filesRepository.fileExistsOperation(at: filePath)
        queue.addOperations([operation], waitUntilFinished: true)

        // then

        let result = try operation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
        XCTAssertFalse(result)
    }

    func testWriteReadFile() throws {
        // given

        let data = "Test String".data(using: .utf8)!
        let filesRepository = FileRepository()
        let filePath = directory.appendingPathComponent("test").path
        let queue = OperationQueue()

        // when

        let save = filesRepository.writeOperation(dataClosure: { data }, at: filePath)
        let fileExists = filesRepository.fileExistsOperation(at: filePath)
        fileExists.addDependency(save)

        let read = filesRepository.readOperation(at: filePath)
        read.addDependency(save)

        queue.addOperations([save, fileExists, read], waitUntilFinished: true)

        // then

        do {
            try save.extractResultData()

            let exists = try fileExists.extractResultData(throwing: BaseOperationError.parentOperationCancelled)

            let readData = try read.extractResultData(throwing: BaseOperationError.parentOperationCancelled)

            XCTAssertTrue(exists)
            XCTAssertEqual(data, readData)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testWriteCopyRemove() {
        // given

        let data = "Test String".data(using: .utf8)!
        let filesRepository = FileRepository()
        let filePath = directory.appendingPathComponent("test").path
        let newPath = directory.appendingPathComponent("new-test").path
        let queue = OperationQueue()

        // when

        let save = filesRepository.writeOperation(dataClosure: { data }, at: filePath)

        let copy = filesRepository.copyOperation(from: filePath, to: newPath)
        copy.addDependency(save)

        let remove = filesRepository.removeOperation(at: filePath)
        remove.addDependency(copy)

        let fileExists = filesRepository.fileExistsOperation(at: filePath)
        fileExists.addDependency(remove)

        let read = filesRepository.readOperation(at: newPath)
        read.addDependency(remove)

        queue.addOperations([save, copy, remove, fileExists, read], waitUntilFinished: true)

        // then

        do {
            try save.extractResultData()
            try copy.extractResultData()
            try remove.extractResultData()

            let exists = try fileExists.extractResultData(throwing: BaseOperationError.parentOperationCancelled)

            let readData = try read.extractResultData(throwing: BaseOperationError.parentOperationCancelled)

            XCTAssertFalse(exists)
            XCTAssertEqual(data, readData)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
