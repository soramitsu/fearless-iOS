// Generated using Sourcery 2.1.3 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT
// swiftlint:disable all

import UIKit
@testable import BigInt
@testable import RobinHood
@testable import SSFChainConnection
@testable import SSFChainRegistry
@testable import SSFExtrinsicKit
@testable import SSFModels
@testable import SSFNetwork
@testable import SSFRuntimeCodingService
@testable import SSFSigner
@testable import SSFStorageQueryKit
@testable import SSFUtils
@testable import SSFXCM

public class XcmDependencyContainerProtocolMock: XcmDependencyContainerProtocol {
    public init() {}

    // MARK: - prepareDeps

    public var prepareDepsThrowableError: Error?
    public var prepareDepsCallsCount = 0
    public var prepareDepsCalled: Bool {
        prepareDepsCallsCount > 0
    }

    public var prepareDepsReturnValue: XcmDeps!
    public var prepareDepsClosure: (() throws -> XcmDeps)?

    public func prepareDeps() throws -> XcmDeps {
        if let error = prepareDepsThrowableError {
            throw error
        }
        prepareDepsCallsCount += 1
        return try prepareDepsClosure.map { try $0() } ?? prepareDepsReturnValue
    }
}
