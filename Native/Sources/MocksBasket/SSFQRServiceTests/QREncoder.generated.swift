// Generated using Sourcery 2.1.3 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT
// swiftlint:disable all

import UIKit
@testable import SSFQRService

public class QREncoderMock: QREncoder {
public init() {}

    //MARK: - encode

    public var encodeWithThrowableError: Error?
    public var encodeWithCallsCount = 0
    public var encodeWithCalled: Bool {
        return encodeWithCallsCount > 0
    }
    public var encodeWithReceivedType: QRType?
    public var encodeWithReceivedInvocations: [QRType] = []
    public var encodeWithReturnValue: Data!
    public var encodeWithClosure: ((QRType) throws -> Data)?

    public func encode(with type: QRType) throws -> Data {
        if let error = encodeWithThrowableError {
            throw error
        }
        encodeWithCallsCount += 1
        encodeWithReceivedType = type
        encodeWithReceivedInvocations.append(type)
        return try encodeWithClosure.map({ try $0(type) }) ?? encodeWithReturnValue
    }

}
