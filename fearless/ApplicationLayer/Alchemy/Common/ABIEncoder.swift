import Foundation
import BigInt

public enum ABIEncoder {
    public static func encode(methodId: Data, arguments: [Any]) throws -> Data {
        var data = methodId
        var arraysData = Data()

        for argument in arguments {
            switch argument {
            case let argument as BigUInt:
                data += pad(data: argument.serialize())
            case let argument as String:
                data += pad(data: try Data(hexString: argument))
            case let argument as Data:
                data += pad(data: argument)
            case let argument as [Data]:
                data += pad(data: BigUInt(arguments.count * 32 + arraysData.count).serialize())
                arraysData += encode(array: argument.map { $0 })
            case let argument as Data:
                data += pad(data: BigUInt(arguments.count * 32 + arraysData.count).serialize())
                arraysData += pad(data: BigUInt(argument.count).serialize()) + argument
            default:
                ()
            }
        }

        return data + arraysData
    }

    private static func encode(array: [Data]) -> Data {
        var data = pad(data: BigUInt(array.count).serialize())

        for item in array {
            data += pad(data: item)
        }

        return data
    }

    private static func pad(data: Data) -> Data {
        Data(repeating: 0, count: max(0, 32 - data.count)) + data
    }
}
