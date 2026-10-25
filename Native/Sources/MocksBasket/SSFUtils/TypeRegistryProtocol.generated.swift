// Generated using Sourcery 2.1.3 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT
// swiftlint:disable all

import UIKit
@testable import SSFUtils
@testable import BigInt

public class TypeRegistryProtocolMock: TypeRegistryProtocol {
public init() {}
    public var registeredTypes: [Node] = []
    public var registeredTypeNames: Set<String> {
        get { return underlyingRegisteredTypeNames }
        set(value) { underlyingRegisteredTypeNames = value }
    }
    public var underlyingRegisteredTypeNames: Set<String>!
    public var registeredOverrides: Set<ConstantPath> {
        get { return underlyingRegisteredOverrides }
        set(value) { underlyingRegisteredOverrides = value }
    }
    public var underlyingRegisteredOverrides: Set<ConstantPath>!

    //MARK: - node

    public var nodeForCallsCount = 0
    public var nodeForCalled: Bool {
        return nodeForCallsCount > 0
    }
    public var nodeForReceivedKey: String?
    public var nodeForReceivedInvocations: [String] = []
    public var nodeForReturnValue: Node?
    public var nodeForClosure: ((String) -> Node?)?

    public func node(for key: String) -> Node? {
        nodeForCallsCount += 1
        nodeForReceivedKey = key
        nodeForReceivedInvocations.append(key)
        return nodeForClosure.map({ $0(key) }) ?? nodeForReturnValue
    }

    //MARK: - override

    public var overrideForConstantNameCallsCount = 0
    public var overrideForConstantNameCalled: Bool {
        return overrideForConstantNameCallsCount > 0
    }
    public var overrideForConstantNameReceivedArguments: (moduleName: String, constantName: String)?
    public var overrideForConstantNameReceivedInvocations: [(moduleName: String, constantName: String)] = []
    public var overrideForConstantNameReturnValue: String?
    public var overrideForConstantNameClosure: ((String, String) -> String?)?

    public func override(for moduleName: String, constantName: String) -> String? {
        overrideForConstantNameCallsCount += 1
        overrideForConstantNameReceivedArguments = (moduleName: moduleName, constantName: constantName)
        overrideForConstantNameReceivedInvocations.append((moduleName: moduleName, constantName: constantName))
        return overrideForConstantNameClosure.map({ $0(moduleName, constantName) }) ?? overrideForConstantNameReturnValue
    }

}
