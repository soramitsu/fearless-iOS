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

public class XcmVersionFetchingMock: XcmVersionFetching {
    public init() {}

    // MARK: - getVersion

    public var getVersionForThrowableError: Error?
    public var getVersionForCallsCount = 0
    public var getVersionForCalled: Bool {
        getVersionForCallsCount > 0
    }

    public var getVersionForReceivedChainId: String?
    public var getVersionForReceivedInvocations: [String] = []
    public var getVersionForReturnValue: XcmCallFactoryVersion!
    public var getVersionForClosure: ((String) throws -> XcmCallFactoryVersion)?

    public func getVersion(for chainId: String) throws -> XcmCallFactoryVersion {
        if let error = getVersionForThrowableError {
            throw error
        }
        getVersionForCallsCount += 1
        getVersionForReceivedChainId = chainId
        getVersionForReceivedInvocations.append(chainId)
        return try getVersionForClosure.map { try $0(chainId) } ?? getVersionForReturnValue
    }
}
