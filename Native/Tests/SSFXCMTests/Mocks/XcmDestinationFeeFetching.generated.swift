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

public class XcmDestinationFeeFetchingMock: XcmDestinationFeeFetching {
    public init() {}

    // MARK: - estimateFee

    public var estimateFeeDestinationChainIdTokenCallsCount = 0
    public var estimateFeeDestinationChainIdTokenCalled: Bool {
        estimateFeeDestinationChainIdTokenCallsCount > 0
    }

    public var estimateFeeDestinationChainIdTokenReceivedArguments: (
        destinationChainId: String,
        token: String
    )?
    public var estimateFeeDestinationChainIdTokenReceivedInvocations: [(
        destinationChainId: String,
        token: String
    )] = []
    public var estimateFeeDestinationChainIdTokenReturnValue: Result<DestXcmFee, Error>!
    public var estimateFeeDestinationChainIdTokenClosure: ((String, String) -> Result<
        DestXcmFee,
        Error
    >)?

    public func estimateFee(
        destinationChainId: String,
        token: String
    ) -> Result<DestXcmFee, Error> {
        estimateFeeDestinationChainIdTokenCallsCount += 1
        estimateFeeDestinationChainIdTokenReceivedArguments = (
            destinationChainId: destinationChainId,
            token: token
        )
        estimateFeeDestinationChainIdTokenReceivedInvocations.append((
            destinationChainId: destinationChainId,
            token: token
        ))
        return estimateFeeDestinationChainIdTokenClosure
            .map { $0(destinationChainId, token) } ?? estimateFeeDestinationChainIdTokenReturnValue
    }
}
