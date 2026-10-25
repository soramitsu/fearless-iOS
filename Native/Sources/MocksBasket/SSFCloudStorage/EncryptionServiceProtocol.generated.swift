// Generated using Sourcery 2.1.3 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT
// swiftlint:disable all

import UIKit
@testable import SSFCloudStorage

public class EncryptionServiceProtocolMock: EncryptionServiceProtocol {
public init() {}

    //MARK: - getDecrypted

    public var getDecryptedFromPasswordThrowableError: Error?
    public var getDecryptedFromPasswordCallsCount = 0
    public var getDecryptedFromPasswordCalled: Bool {
        return getDecryptedFromPasswordCallsCount > 0
    }
    public var getDecryptedFromPasswordReceivedArguments: (message: String?, password: String)?
    public var getDecryptedFromPasswordReceivedInvocations: [(message: String?, password: String)] = []
    public var getDecryptedFromPasswordReturnValue: String?
    public var getDecryptedFromPasswordClosure: ((String?, String) throws -> String?)?

    public func getDecrypted(from message: String?, password: String) throws -> String? {
        if let error = getDecryptedFromPasswordThrowableError {
            throw error
        }
        getDecryptedFromPasswordCallsCount += 1
        getDecryptedFromPasswordReceivedArguments = (message: message, password: password)
        getDecryptedFromPasswordReceivedInvocations.append((message: message, password: password))
        return try getDecryptedFromPasswordClosure.map({ try $0(message, password) }) ?? getDecryptedFromPasswordReturnValue
    }

    //MARK: - createEncryptedData

    public var createEncryptedDataWithMessageThrowableError: Error?
    public var createEncryptedDataWithMessageCallsCount = 0
    public var createEncryptedDataWithMessageCalled: Bool {
        return createEncryptedDataWithMessageCallsCount > 0
    }
    public var createEncryptedDataWithMessageReceivedArguments: (password: String, message: String?)?
    public var createEncryptedDataWithMessageReceivedInvocations: [(password: String, message: String?)] = []
    public var createEncryptedDataWithMessageReturnValue: Data?
    public var createEncryptedDataWithMessageClosure: ((String, String?) throws -> Data?)?

    public func createEncryptedData(with password: String, message: String?) throws -> Data? {
        if let error = createEncryptedDataWithMessageThrowableError {
            throw error
        }
        createEncryptedDataWithMessageCallsCount += 1
        createEncryptedDataWithMessageReceivedArguments = (password: password, message: message)
        createEncryptedDataWithMessageReceivedInvocations.append((password: password, message: message))
        return try createEncryptedDataWithMessageClosure.map({ try $0(password, message) }) ?? createEncryptedDataWithMessageReturnValue
    }

}
