import Foundation
import SSFModels

public enum StoragePathMock: StorageCodingPathProtocol {
    public static var allCases: [StoragePathMock] = []

    public var moduleName: String {
        path.moduleName
    }

    public var itemName: String {
        path.itemName
    }

    public var path: (moduleName: String, itemName: String) {
        switch self {
        case let .custom(moduleName, itemName):
            return (moduleName: moduleName, itemName: itemName)
        }
    }

    case custom(moduleName: String, itemName: String)
}
