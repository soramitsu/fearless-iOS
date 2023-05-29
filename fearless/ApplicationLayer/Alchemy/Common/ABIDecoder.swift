import Foundation
import BigInt
import IrohaCrypto

enum ABIDecoderError: Error {
    case badSignature
}

final class ABIDecoder {
    public class func decode(inputArguments: Data, argumentTypes: [Any]) -> [Any] {
        var position = 0
        var parsedArguments = [Any]()

        for type in argumentTypes {
            switch type {
            case is BigUInt.Type:
                let data = Data(inputArguments[position ..< position + 32])
                parsedArguments.append(BigUInt(data))
                position += 32
            case is Data.Type:
                let dataPosition = parseInt(data: inputArguments[position ..< position + 32])
                let data: Data = parseData(startPosition: dataPosition, inputArguments: inputArguments)
                parsedArguments.append(data)
                position += 32

            case is [Data].Type:
                let dataPosition = parseInt(data: inputArguments[position ..< position + 32])
                let data: [Data] = parseDataArray(startPosition: dataPosition, inputArguments: inputArguments)
                parsedArguments.append(data)
                position += 32

            case let object as StructParameter:
                let argumentsPosition = parseInt(data: inputArguments[position ..< position + 32])
                let data: [Any] = decode(inputArguments: Data(inputArguments[argumentsPosition ..< inputArguments.count]), argumentTypes: object.arguments)
                parsedArguments.append(data)
                position += 32

            default: ()
            }
        }

        return parsedArguments
    }

    private class func parseInt(data: Data) -> Int {
        Data(data.reversed()).to(type: Int.self)
    }

    private class func parseData(startPosition: Int, inputArguments: Data) -> Data {
        let dataStartPosition = startPosition + 32
        let size = parseInt(data: inputArguments[startPosition ..< dataStartPosition])
        return Data(inputArguments[dataStartPosition ..< (dataStartPosition + size)])
    }

    private class func parseDataArray(startPosition: Int, inputArguments: Data) -> [Data] {
        let arrayStartPosition = startPosition + 32
        let size = parseInt(data: inputArguments[startPosition ..< arrayStartPosition])
        var dataArray = [Data]()

        for i in 0 ..< size {
            dataArray.append(Data(inputArguments[(arrayStartPosition + 32 * i) ..< (arrayStartPosition + 32 * (i + 1))]))
        }

        return dataArray
    }
}
