// Generated using Sourcery 2.1.3 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT
// swiftlint:disable all

import UIKit
@testable import BigInt
@testable import SSFUtils

class TypeRegistryProtocolMock: TypeRegistryProtocol {
    var registeredTypes: [Node] = []
    var registeredTypeNames: Set<String> {
        get { underlyingRegisteredTypeNames }
        set(value) { underlyingRegisteredTypeNames = value }
    }

    var underlyingRegisteredTypeNames: Set<String>!
    var registeredOverrides: Set<ConstantPath> {
        get { underlyingRegisteredOverrides }
        set(value) { underlyingRegisteredOverrides = value }
    }

    var underlyingRegisteredOverrides: Set<ConstantPath>!

    // MARK: - node

    var nodeForCallsCount = 0
    var nodeForCalled: Bool {
        nodeForCallsCount > 0
    }

    var nodeForReceivedKey: String?
    var nodeForReceivedInvocations: [String] = []
    var nodeForReturnValue: Node?
    var nodeForClosure: ((String) -> Node?)?

    func node(for key: String) -> Node? {
        nodeForCallsCount += 1
        nodeForReceivedKey = key
        nodeForReceivedInvocations.append(key)
        return nodeForClosure.map { $0(key) } ?? nodeForReturnValue
    }

    // MARK: - override

    var overrideForConstantNameCallsCount = 0
    var overrideForConstantNameCalled: Bool {
        overrideForConstantNameCallsCount > 0
    }

    var overrideForConstantNameReceivedArguments: (moduleName: String, constantName: String)?
    var overrideForConstantNameReceivedInvocations: [(moduleName: String, constantName: String)] =
        []
    var overrideForConstantNameReturnValue: String?
    var overrideForConstantNameClosure: ((String, String) -> String?)?

    func override(for moduleName: String, constantName: String) -> String? {
        overrideForConstantNameCallsCount += 1
        overrideForConstantNameReceivedArguments = (
            moduleName: moduleName,
            constantName: constantName
        )
        overrideForConstantNameReceivedInvocations.append((
            moduleName: moduleName,
            constantName: constantName
        ))
        return overrideForConstantNameClosure
            .map { $0(moduleName, constantName) } ?? overrideForConstantNameReturnValue
    }
}
