// Generated using Sourcery 2.1.3 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT
// swiftlint:disable all

import UIKit
@testable import SSFQRService

public class QRDecoderMock: QRDecoder {
public init() {}

    //MARK: - decode

    public var decodeDataThrowableError: Error?
    public var decodeDataCallsCount = 0
    public var decodeDataCalled: Bool {
        return decodeDataCallsCount > 0
    }
    public var decodeDataReceivedData: Data?
    public var decodeDataReceivedInvocations: [Data] = []
    public var decodeDataReturnValue: QRInfoType!
    public var decodeDataClosure: ((Data) throws -> QRInfoType)?

    public func decode(data: Data) throws -> QRInfoType {
        if let error = decodeDataThrowableError {
            throw error
        }
        decodeDataCallsCount += 1
        decodeDataReceivedData = data
        decodeDataReceivedInvocations.append(data)
        return try decodeDataClosure.map({ try $0(data) }) ?? decodeDataReturnValue
    }

}
