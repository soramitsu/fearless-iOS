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

public class XcmDependencyContainerProtocolMock: XcmDependencyContainerProtocol {
public init() {}

    //MARK: - prepareDeps

    public var prepareDepsThrowableError: Error?
    public var prepareDepsCallsCount = 0
    public var prepareDepsCalled: Bool {
        return prepareDepsCallsCount > 0
    }
    public var prepareDepsReturnValue: XcmDeps!
    public var prepareDepsClosure: (() throws -> XcmDeps)?

    public func prepareDeps() throws -> XcmDeps {
        if let error = prepareDepsThrowableError {
            throw error
        }
        prepareDepsCallsCount += 1
        return try prepareDepsClosure.map({ try $0() }) ?? prepareDepsReturnValue
    }

}
