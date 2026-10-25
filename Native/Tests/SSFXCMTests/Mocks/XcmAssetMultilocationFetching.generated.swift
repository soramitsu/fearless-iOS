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

public class XcmAssetMultilocationFetchingMock: XcmAssetMultilocationFetching {
    public init() {}

    // MARK: - versionedMultilocation

    public var versionedMultilocationOriginAssetIdDestChainIdThrowableError: Error?
    public var versionedMultilocationOriginAssetIdDestChainIdCallsCount = 0
    public var versionedMultilocationOriginAssetIdDestChainIdCalled: Bool {
        versionedMultilocationOriginAssetIdDestChainIdCallsCount > 0
    }

    public var versionedMultilocationOriginAssetIdDestChainIdReceivedArguments: (
        originAssetId: String,
        destChainId: ChainModel.Id
    )?
    public var versionedMultilocationOriginAssetIdDestChainIdReceivedInvocations: [(
        originAssetId: String,
        destChainId: ChainModel.Id
    )] = []
    public var versionedMultilocationOriginAssetIdDestChainIdReturnValue: AssetMultilocation!
    public var versionedMultilocationOriginAssetIdDestChainIdClosure: ((
        String,
        ChainModel.Id
    ) throws -> AssetMultilocation)?

    public func versionedMultilocation(
        originAssetId: String,
        destChainId: ChainModel.Id
    ) throws -> AssetMultilocation {
        if let error = versionedMultilocationOriginAssetIdDestChainIdThrowableError {
            throw error
        }
        versionedMultilocationOriginAssetIdDestChainIdCallsCount += 1
        versionedMultilocationOriginAssetIdDestChainIdReceivedArguments = (
            originAssetId: originAssetId,
            destChainId: destChainId
        )
        versionedMultilocationOriginAssetIdDestChainIdReceivedInvocations.append((
            originAssetId: originAssetId,
            destChainId: destChainId
        ))
        return try versionedMultilocationOriginAssetIdDestChainIdClosure.map { try $0(
            originAssetId,
            destChainId
        ) } ?? versionedMultilocationOriginAssetIdDestChainIdReturnValue
    }
}
