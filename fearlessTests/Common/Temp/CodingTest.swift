import Foundation
import XCTest
import FearlessUtils

class ScaleUnit32Tests: XCTestCase {
    private struct TestExample {
        let value: UInt32
        let result: Data
    }
    
    private let testVectors: [TestExample] = [
        TestExample(value: 16909060, result: Data([4, 3, 2, 1])),
        TestExample(value: 67305985, result: Data([1, 2, 3, 4]))
    ]
    
    func testEncoding() throws {
        for test in testVectors {
            let encoder = ScaleEncoder()
            try test.value.encode(scaleEncoder: encoder)
            print(test.result)
            XCTAssertEqual(encoder.encode(), test.result)
        }
    }
    
    func testDecoding() throws {
        for test in testVectors {
            let decoder = try ScaleDecoder(data: test.result)
            let value = try UInt32(scaleDecoder: decoder)
            print(test.result)
            XCTAssertEqual(value, test.value)
        }
    }
    
    func testRepeatCoding() throws {
        var timeSteps: Array<Double> = []
        let encoder = ScaleEncoder()
        for step in 1...5 {
            let startDate = Date()
            for _ in 1...10000 {
                try UInt32.random(in: 0...10000).encode(scaleEncoder: encoder)
                let result: Data = encoder.encode()
                _ = result.toHex()
            }
            let endDate = Date()
            let measureTime = endDate.timeIntervalSince(startDate)
            print("time(\(step)): \(measureTime)")
            timeSteps.append(measureTime)
        }
        print("mean time: \(timeSteps.reduce(0, +) / Double(timeSteps.count))")
    }
}
