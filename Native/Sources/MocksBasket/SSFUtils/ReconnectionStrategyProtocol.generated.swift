// Generated using Sourcery 2.1.3 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT
// swiftlint:disable all

import UIKit
@testable import SSFUtils
@testable import BigInt

public class ReconnectionStrategyProtocolMock: ReconnectionStrategyProtocol {
public init() {}

    //MARK: - reconnectAfter

    public var reconnectAfterAttemptCallsCount = 0
    public var reconnectAfterAttemptCalled: Bool {
        return reconnectAfterAttemptCallsCount > 0
    }
    public var reconnectAfterAttemptReceivedAttempt: Int?
    public var reconnectAfterAttemptReceivedInvocations: [Int] = []
    public var reconnectAfterAttemptReturnValue: TimeInterval?
    public var reconnectAfterAttemptClosure: ((Int) -> TimeInterval?)?

    public func reconnectAfter(attempt: Int) -> TimeInterval? {
        reconnectAfterAttemptCallsCount += 1
        reconnectAfterAttemptReceivedAttempt = attempt
        reconnectAfterAttemptReceivedInvocations.append(attempt)
        return reconnectAfterAttemptClosure.map({ $0(attempt) }) ?? reconnectAfterAttemptReturnValue
    }

}
