import Foundation

struct UsedRuntimePaths {
    private let storageCodingCases = StorageCodingPath.allCases
    private let callCodingCases = CallCodingPath.allCases
    private let constantsCodingCases = ConstantCodingPath.allCases
    private let sabstrateCodingCases = SubstrateCallPath.allCases

    lazy var usedRuntimePaths: [String: [String]] = {
        var modules = [String: [String]]()

        storageCodingCases.forEach {
            guard var itemNames = modules[$0.moduleName] else {
                modules[$0.moduleName] = [$0.itemName]
                return
            }
            itemNames.append($0.itemName)
            modules[$0.moduleName] = itemNames
        }

        callCodingCases.forEach {
            guard var itemNames = modules[$0.moduleName] else {
                modules[$0.moduleName] = [$0.callName]
                return
            }
            itemNames.append($0.callName)
            modules[$0.moduleName] = itemNames
        }

        constantsCodingCases.forEach {
            guard var itemNames = modules[$0.moduleName] else {
                modules[$0.moduleName] = [$0.constantName]
                return
            }
            itemNames.append($0.constantName)
            modules[$0.moduleName] = itemNames
        }

        sabstrateCodingCases.forEach {
            guard var itemNames = modules[$0.moduleName] else {
                modules[$0.moduleName] = [$0.callName]
                return
            }
            itemNames.append($0.callName)
            modules[$0.moduleName] = itemNames
        }

        return modules
    }()
}
