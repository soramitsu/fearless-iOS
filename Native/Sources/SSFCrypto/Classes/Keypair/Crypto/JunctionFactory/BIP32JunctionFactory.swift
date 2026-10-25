import BigInt
import Foundation
import IrohaCrypto

public enum BIP32JunctionFactoryError: Error {
    case invalidBIP32Junction
    case invalidBIP32HardJunction
}

public final class BIP32JunctionFactory: JunctionFactory {
    static let hardKeyFlag: UInt32 = 0x8000_0000

    override public init() {
        super.init()
    }

    override func createChaincodeFromJunction(
        _ junction: String,
        type: ChaincodeType
    ) throws -> Chaincode {
        guard var numericJunction = UInt32(junction) else {
            throw BIP32JunctionFactoryError.invalidBIP32Junction
        }

        guard numericJunction < Self.hardKeyFlag else {
            throw BIP32JunctionFactoryError.invalidBIP32HardJunction
        }

        if type == .hard {
            numericJunction |= Self.hardKeyFlag
        }

        let junctionBytes = withUnsafeBytes(of: numericJunction.bigEndian) {
            Data($0)
        }

        return Chaincode(data: junctionBytes, type: type)
    }
}
