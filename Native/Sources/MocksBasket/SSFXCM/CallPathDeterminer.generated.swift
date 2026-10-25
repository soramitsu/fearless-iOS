// Generated using Sourcery 2.1.3 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT
// swiftlint:disable all

import UIKit
@testable import SSFXCM
@testable import SSFUtils
@testable import SSFNetwork
@testable import SSFModels
@testable import RobinHood
@testable import BigInt
@testable import SSFExtrinsicKit
@testable import SSFChainRegistry
@testable import SSFRuntimeCodingService
@testable import SSFSigner
@testable import SSFChainConnection
@testable import SSFStorageQueryKit

public class CallPathDeterminerMock: CallPathDeterminer {
public init() {}

    //MARK: - determineCallPath

    public var determineCallPathFromDestThrowableError: Error?
    public var determineCallPathFromDestCallsCount = 0
    public var determineCallPathFromDestCalled: Bool {
        return determineCallPathFromDestCallsCount > 0
    }
    public var determineCallPathFromDestReceivedArguments: (from: XcmChainType, dest: XcmChainType)?
    public var determineCallPathFromDestReceivedInvocations: [(from: XcmChainType, dest: XcmChainType)] = []
    public var determineCallPathFromDestReturnValue: XcmCallPath!
    public var determineCallPathFromDestClosure: ((XcmChainType, XcmChainType) throws -> XcmCallPath)?

    public func determineCallPath(from: XcmChainType, dest: XcmChainType) throws -> XcmCallPath {
        if let error = determineCallPathFromDestThrowableError {
            throw error
        }
        determineCallPathFromDestCallsCount += 1
        determineCallPathFromDestReceivedArguments = (from: from, dest: dest)
        determineCallPathFromDestReceivedInvocations.append((from: from, dest: dest))
        return try determineCallPathFromDestClosure.map({ try $0(from, dest) }) ?? determineCallPathFromDestReturnValue
    }

}
