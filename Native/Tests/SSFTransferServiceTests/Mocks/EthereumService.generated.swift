// Generated using Sourcery 2.1.3 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT
// swiftlint:disable all

import UIKit
@testable import SSFModels
@testable import SSFTransferService
@testable import Web3
@testable import Web3ContractABI

public class EthereumServiceMock: EthereumService {
    public init() {}
    public var connection: Web3.Eth {
        get { underlyingConnection }
        set(value) { underlyingConnection = value }
    }

    public var underlyingConnection: Web3.Eth!
    public var hasSubscription: Bool {
        get { underlyingHasSubscription }
        set(value) { underlyingHasSubscription = value }
    }

    public var underlyingHasSubscription: Bool!

    // MARK: - send

    public var sendThrowableError: Error?
    public var sendCallsCount = 0
    public var sendCalled: Bool {
        sendCallsCount > 0
    }

    public var sendReceivedTransaction: EthereumSignedTransaction?
    public var sendReceivedInvocations: [EthereumSignedTransaction] = []
    public var sendReturnValue: EthereumData!
    public var sendClosure: ((EthereumSignedTransaction) throws -> EthereumData)?

    public func send(_ transaction: EthereumSignedTransaction) throws -> EthereumData {
        if let error = sendThrowableError {
            throw error
        }
        sendCallsCount += 1
        sendReceivedTransaction = transaction
        sendReceivedInvocations.append(transaction)
        return try sendClosure.map { try $0(transaction) } ?? sendReturnValue
    }

    // MARK: - queryGasLimit

    public var queryGasLimitCallThrowableError: Error?
    public var queryGasLimitCallCallsCount = 0
    public var queryGasLimitCallCalled: Bool {
        queryGasLimitCallCallsCount > 0
    }

    public var queryGasLimitCallReceivedCall: EthereumCall?
    public var queryGasLimitCallReceivedInvocations: [EthereumCall] = []
    public var queryGasLimitCallReturnValue: EthereumQuantity!
    public var queryGasLimitCallClosure: ((EthereumCall) throws -> EthereumQuantity)?

    public func queryGasLimit(call: EthereumCall) throws -> EthereumQuantity {
        if let error = queryGasLimitCallThrowableError {
            throw error
        }
        queryGasLimitCallCallsCount += 1
        queryGasLimitCallReceivedCall = call
        queryGasLimitCallReceivedInvocations.append(call)
        return try queryGasLimitCallClosure.map { try $0(call) } ?? queryGasLimitCallReturnValue
    }

    // MARK: - queryGasLimit

    public var queryGasLimitFromAmountTransferThrowableError: Error?
    public var queryGasLimitFromAmountTransferCallsCount = 0
    public var queryGasLimitFromAmountTransferCalled: Bool {
        queryGasLimitFromAmountTransferCallsCount > 0
    }

    public var queryGasLimitFromAmountTransferReceivedArguments: (
        from: EthereumAddress?,
        amount: EthereumQuantity?,
        transfer: SolidityInvocation
    )?
    public var queryGasLimitFromAmountTransferReceivedInvocations: [(
        from: EthereumAddress?,
        amount: EthereumQuantity?,
        transfer: SolidityInvocation
    )] = []
    public var queryGasLimitFromAmountTransferReturnValue: EthereumQuantity!
    public var queryGasLimitFromAmountTransferClosure: ((
        EthereumAddress?,
        EthereumQuantity?,
        SolidityInvocation
    ) throws -> EthereumQuantity)?

    public func queryGasLimit(
        from: EthereumAddress?,
        amount: EthereumQuantity?,
        transfer: SolidityInvocation
    ) throws -> EthereumQuantity {
        if let error = queryGasLimitFromAmountTransferThrowableError {
            throw error
        }
        queryGasLimitFromAmountTransferCallsCount += 1
        queryGasLimitFromAmountTransferReceivedArguments = (
            from: from,
            amount: amount,
            transfer: transfer
        )
        queryGasLimitFromAmountTransferReceivedInvocations.append((
            from: from,
            amount: amount,
            transfer: transfer
        ))
        return try queryGasLimitFromAmountTransferClosure
            .map { try $0(from, amount, transfer) } ?? queryGasLimitFromAmountTransferReturnValue
    }

    // MARK: - queryGasPrice

    public var queryGasPriceThrowableError: Error?
    public var queryGasPriceCallsCount = 0
    public var queryGasPriceCalled: Bool {
        queryGasPriceCallsCount > 0
    }

    public var queryGasPriceReturnValue: EthereumQuantity!
    public var queryGasPriceClosure: (() throws -> EthereumQuantity)?

    public func queryGasPrice() throws -> EthereumQuantity {
        if let error = queryGasPriceThrowableError {
            throw error
        }
        queryGasPriceCallsCount += 1
        return try queryGasPriceClosure.map { try $0() } ?? queryGasPriceReturnValue
    }

    // MARK: - queryMaxPriorityFeePerGas

    public var queryMaxPriorityFeePerGasThrowableError: Error?
    public var queryMaxPriorityFeePerGasCallsCount = 0
    public var queryMaxPriorityFeePerGasCalled: Bool {
        queryMaxPriorityFeePerGasCallsCount > 0
    }

    public var queryMaxPriorityFeePerGasReturnValue: EthereumQuantity!
    public var queryMaxPriorityFeePerGasClosure: (() throws -> EthereumQuantity)?

    public func queryMaxPriorityFeePerGas() throws -> EthereumQuantity {
        if let error = queryMaxPriorityFeePerGasThrowableError {
            throw error
        }
        queryMaxPriorityFeePerGasCallsCount += 1
        return try queryMaxPriorityFeePerGasClosure
            .map { try $0() } ?? queryMaxPriorityFeePerGasReturnValue
    }

    // MARK: - queryNonce

    public var queryNonceEthereumAddressThrowableError: Error?
    public var queryNonceEthereumAddressCallsCount = 0
    public var queryNonceEthereumAddressCalled: Bool {
        queryNonceEthereumAddressCallsCount > 0
    }

    public var queryNonceEthereumAddressReceivedEthereumAddress: EthereumAddress?
    public var queryNonceEthereumAddressReceivedInvocations: [EthereumAddress] = []
    public var queryNonceEthereumAddressReturnValue: EthereumQuantity!
    public var queryNonceEthereumAddressClosure: ((EthereumAddress) throws -> EthereumQuantity)?

    public func queryNonce(ethereumAddress: EthereumAddress) throws -> EthereumQuantity {
        if let error = queryNonceEthereumAddressThrowableError {
            throw error
        }
        queryNonceEthereumAddressCallsCount += 1
        queryNonceEthereumAddressReceivedEthereumAddress = ethereumAddress
        queryNonceEthereumAddressReceivedInvocations.append(ethereumAddress)
        return try queryNonceEthereumAddressClosure
            .map { try $0(ethereumAddress) } ?? queryNonceEthereumAddressReturnValue
    }

    // MARK: - checkChainSupportEip1559

    public var checkChainSupportEip1559CallsCount = 0
    public var checkChainSupportEip1559Called: Bool {
        checkChainSupportEip1559CallsCount > 0
    }

    public var checkChainSupportEip1559ReturnValue: Bool!
    public var checkChainSupportEip1559Closure: (() -> Bool)?

    public func checkChainSupportEip1559() -> Bool {
        checkChainSupportEip1559CallsCount += 1
        return checkChainSupportEip1559Closure.map { $0() } ?? checkChainSupportEip1559ReturnValue
    }

    // MARK: - unsubscribe

    public var unsubscribeSubscriptionIdThrowableError: Error?
    public var unsubscribeSubscriptionIdCallsCount = 0
    public var unsubscribeSubscriptionIdCalled: Bool {
        unsubscribeSubscriptionIdCallsCount > 0
    }

    public var unsubscribeSubscriptionIdReceivedSubscriptionId: String?
    public var unsubscribeSubscriptionIdReceivedInvocations: [String] = []
    public var unsubscribeSubscriptionIdReturnValue: Bool!
    public var unsubscribeSubscriptionIdClosure: ((String) throws -> Bool)?

    public func unsubscribe(subscriptionId: String) throws -> Bool {
        if let error = unsubscribeSubscriptionIdThrowableError {
            throw error
        }
        unsubscribeSubscriptionIdCallsCount += 1
        unsubscribeSubscriptionIdReceivedSubscriptionId = subscriptionId
        unsubscribeSubscriptionIdReceivedInvocations.append(subscriptionId)
        return try unsubscribeSubscriptionIdClosure
            .map { try $0(subscriptionId) } ?? unsubscribeSubscriptionIdReturnValue
    }

    // MARK: - getBlockByNumber

    public var getBlockByNumberBlockFullTransactionObjectsThrowableError: Error?
    public var getBlockByNumberBlockFullTransactionObjectsCallsCount = 0
    public var getBlockByNumberBlockFullTransactionObjectsCalled: Bool {
        getBlockByNumberBlockFullTransactionObjectsCallsCount > 0
    }

    public var getBlockByNumberBlockFullTransactionObjectsReceivedArguments: (
        block: EthereumQuantityTag,
        fullTransactionObjects: Bool
    )?
    public var getBlockByNumberBlockFullTransactionObjectsReceivedInvocations: [(
        block: EthereumQuantityTag,
        fullTransactionObjects: Bool
    )] = []
    public var getBlockByNumberBlockFullTransactionObjectsReturnValue: EthereumBlockObject?
    public var getBlockByNumberBlockFullTransactionObjectsClosure: ((
        EthereumQuantityTag,
        Bool
    ) throws -> EthereumBlockObject?)?

    public func getBlockByNumber(
        block: EthereumQuantityTag,
        fullTransactionObjects: Bool
    ) throws -> EthereumBlockObject? {
        if let error = getBlockByNumberBlockFullTransactionObjectsThrowableError {
            throw error
        }
        getBlockByNumberBlockFullTransactionObjectsCallsCount += 1
        getBlockByNumberBlockFullTransactionObjectsReceivedArguments = (
            block: block,
            fullTransactionObjects: fullTransactionObjects
        )
        getBlockByNumberBlockFullTransactionObjectsReceivedInvocations.append((
            block: block,
            fullTransactionObjects: fullTransactionObjects
        ))
        return try getBlockByNumberBlockFullTransactionObjectsClosure.map { try $0(
            block,
            fullTransactionObjects
        ) } ?? getBlockByNumberBlockFullTransactionObjectsReturnValue
    }
}
