// Generated using Sourcery 2.1.3 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT
// swiftlint:disable all

import UIKit
@testable import IrohaCrypto
@testable import RobinHood
@testable import SSFCrypto
@testable import SSFExtrinsicKit
@testable import SSFModels
@testable import SSFRuntimeCodingService
@testable import SSFSigner
@testable import SSFUtils

public class ExtrinsicServiceProtocolMock: ExtrinsicServiceProtocol {
    public init() {}

    // MARK: - estimateFee

    public var estimateFeeRunningInCompletionCallsCount = 0
    public var estimateFeeRunningInCompletionCalled: Bool {
        estimateFeeRunningInCompletionCallsCount > 0
    }

    public var estimateFeeRunningInCompletionReceivedArguments: (
        closure: ExtrinsicBuilderClosure,
        queue: DispatchQueue,
        completionClosure: EstimateFeeClosure
    )?
    public var estimateFeeRunningInCompletionReceivedInvocations: [(
        closure: ExtrinsicBuilderClosure,
        queue: DispatchQueue,
        completionClosure: EstimateFeeClosure
    )] = []
    public var estimateFeeRunningInCompletionClosure: ((
        @escaping ExtrinsicBuilderClosure,
        DispatchQueue,
        @escaping EstimateFeeClosure
    ) -> Void)?

    public func estimateFee(
        _ closure: @escaping ExtrinsicBuilderClosure,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping EstimateFeeClosure
    ) {
        estimateFeeRunningInCompletionCallsCount += 1
        estimateFeeRunningInCompletionReceivedArguments = (
            closure: closure,
            queue: queue,
            completionClosure: completionClosure
        )
        estimateFeeRunningInCompletionReceivedInvocations.append((
            closure: closure,
            queue: queue,
            completionClosure: completionClosure
        ))
        estimateFeeRunningInCompletionClosure?(closure, queue, completionClosure)
    }

    // MARK: - estimateFee

    public var estimateFeeRunningInNumberOfExtrinsicsCompletionCallsCount = 0
    public var estimateFeeRunningInNumberOfExtrinsicsCompletionCalled: Bool {
        estimateFeeRunningInNumberOfExtrinsicsCompletionCallsCount > 0
    }

    public var estimateFeeRunningInNumberOfExtrinsicsCompletionReceivedArguments: (
        closure: ExtrinsicBuilderIndexedClosure,
        queue: DispatchQueue,
        numberOfExtrinsics: Int,
        completionClosure: EstimateFeeIndexedClosure
    )?
    public var estimateFeeRunningInNumberOfExtrinsicsCompletionReceivedInvocations: [(
        closure: ExtrinsicBuilderIndexedClosure,
        queue: DispatchQueue,
        numberOfExtrinsics: Int,
        completionClosure: EstimateFeeIndexedClosure
    )] = []
    public var estimateFeeRunningInNumberOfExtrinsicsCompletionClosure: ((
        @escaping ExtrinsicBuilderIndexedClosure,
        DispatchQueue,
        Int,
        @escaping EstimateFeeIndexedClosure
    ) -> Void)?

    public func estimateFee(
        _ closure: @escaping ExtrinsicBuilderIndexedClosure,
        runningIn queue: DispatchQueue,
        numberOfExtrinsics: Int,
        completion completionClosure: @escaping EstimateFeeIndexedClosure
    ) {
        estimateFeeRunningInNumberOfExtrinsicsCompletionCallsCount += 1
        estimateFeeRunningInNumberOfExtrinsicsCompletionReceivedArguments = (
            closure: closure,
            queue: queue,
            numberOfExtrinsics: numberOfExtrinsics,
            completionClosure: completionClosure
        )
        estimateFeeRunningInNumberOfExtrinsicsCompletionReceivedInvocations.append((
            closure: closure,
            queue: queue,
            numberOfExtrinsics: numberOfExtrinsics,
            completionClosure: completionClosure
        ))
        estimateFeeRunningInNumberOfExtrinsicsCompletionClosure?(
            closure,
            queue,
            numberOfExtrinsics,
            completionClosure
        )
    }

    // MARK: - submit

    public var submitSignerRunningInCompletionCallsCount = 0
    public var submitSignerRunningInCompletionCalled: Bool {
        submitSignerRunningInCompletionCallsCount > 0
    }

    public var submitSignerRunningInCompletionReceivedArguments: (
        closure: ExtrinsicBuilderClosure,
        signer: TransactionSignerProtocol,
        queue: DispatchQueue,
        completionClosure: ExtrinsicSubmitClosure
    )?
    public var submitSignerRunningInCompletionReceivedInvocations: [(
        closure: ExtrinsicBuilderClosure,
        signer: TransactionSignerProtocol,
        queue: DispatchQueue,
        completionClosure: ExtrinsicSubmitClosure
    )] = []
    public var submitSignerRunningInCompletionClosure: ((
        @escaping ExtrinsicBuilderClosure,
        TransactionSignerProtocol,
        DispatchQueue,
        @escaping ExtrinsicSubmitClosure
    ) -> Void)?

    public func submit(
        _ closure: @escaping ExtrinsicBuilderClosure,
        signer: TransactionSignerProtocol,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping ExtrinsicSubmitClosure
    ) {
        submitSignerRunningInCompletionCallsCount += 1
        submitSignerRunningInCompletionReceivedArguments = (
            closure: closure,
            signer: signer,
            queue: queue,
            completionClosure: completionClosure
        )
        submitSignerRunningInCompletionReceivedInvocations.append((
            closure: closure,
            signer: signer,
            queue: queue,
            completionClosure: completionClosure
        ))
        submitSignerRunningInCompletionClosure?(closure, signer, queue, completionClosure)
    }

    // MARK: - submit

    public var submitSignerRunningInNumberOfExtrinsicsCompletionCallsCount = 0
    public var submitSignerRunningInNumberOfExtrinsicsCompletionCalled: Bool {
        submitSignerRunningInNumberOfExtrinsicsCompletionCallsCount > 0
    }

    public var submitSignerRunningInNumberOfExtrinsicsCompletionReceivedArguments: (
        closure: ExtrinsicBuilderIndexedClosure,
        signer: TransactionSignerProtocol,
        queue: DispatchQueue,
        numberOfExtrinsics: Int,
        completionClosure: ExtrinsicSubmitIndexedClosure
    )?
    public var submitSignerRunningInNumberOfExtrinsicsCompletionReceivedInvocations: [(
        closure: ExtrinsicBuilderIndexedClosure,
        signer: TransactionSignerProtocol,
        queue: DispatchQueue,
        numberOfExtrinsics: Int,
        completionClosure: ExtrinsicSubmitIndexedClosure
    )] = []
    public var submitSignerRunningInNumberOfExtrinsicsCompletionClosure: ((
        @escaping ExtrinsicBuilderIndexedClosure,
        TransactionSignerProtocol,
        DispatchQueue,
        Int,
        @escaping ExtrinsicSubmitIndexedClosure
    ) -> Void)?

    public func submit(
        _ closure: @escaping ExtrinsicBuilderIndexedClosure,
        signer: TransactionSignerProtocol,
        runningIn queue: DispatchQueue,
        numberOfExtrinsics: Int,
        completion completionClosure: @escaping ExtrinsicSubmitIndexedClosure
    ) {
        submitSignerRunningInNumberOfExtrinsicsCompletionCallsCount += 1
        submitSignerRunningInNumberOfExtrinsicsCompletionReceivedArguments = (
            closure: closure,
            signer: signer,
            queue: queue,
            numberOfExtrinsics: numberOfExtrinsics,
            completionClosure: completionClosure
        )
        submitSignerRunningInNumberOfExtrinsicsCompletionReceivedInvocations.append((
            closure: closure,
            signer: signer,
            queue: queue,
            numberOfExtrinsics: numberOfExtrinsics,
            completionClosure: completionClosure
        ))
        submitSignerRunningInNumberOfExtrinsicsCompletionClosure?(
            closure,
            signer,
            queue,
            numberOfExtrinsics,
            completionClosure
        )
    }

    // MARK: - submitAndWatch

    public var submitAndWatchSignerRunningInCompletionCallsCount = 0
    public var submitAndWatchSignerRunningInCompletionCalled: Bool {
        submitAndWatchSignerRunningInCompletionCallsCount > 0
    }

    public var submitAndWatchSignerRunningInCompletionReceivedArguments: (
        closure: ExtrinsicBuilderClosure,
        signer: TransactionSignerProtocol,
        queue: DispatchQueue,
        completionClosure: ExtrinsicSubmitAndWatchClosure
    )?
    public var submitAndWatchSignerRunningInCompletionReceivedInvocations: [(
        closure: ExtrinsicBuilderClosure,
        signer: TransactionSignerProtocol,
        queue: DispatchQueue,
        completionClosure: ExtrinsicSubmitAndWatchClosure
    )] = []
    public var submitAndWatchSignerRunningInCompletionClosure: ((
        @escaping ExtrinsicBuilderClosure,
        TransactionSignerProtocol,
        DispatchQueue,
        @escaping ExtrinsicSubmitAndWatchClosure
    ) -> Void)?

    public func submitAndWatch(
        _ closure: @escaping ExtrinsicBuilderClosure,
        signer: TransactionSignerProtocol,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping ExtrinsicSubmitAndWatchClosure
    ) {
        submitAndWatchSignerRunningInCompletionCallsCount += 1
        submitAndWatchSignerRunningInCompletionReceivedArguments = (
            closure: closure,
            signer: signer,
            queue: queue,
            completionClosure: completionClosure
        )
        submitAndWatchSignerRunningInCompletionReceivedInvocations.append((
            closure: closure,
            signer: signer,
            queue: queue,
            completionClosure: completionClosure
        ))
        submitAndWatchSignerRunningInCompletionClosure?(closure, signer, queue, completionClosure)
    }
}
