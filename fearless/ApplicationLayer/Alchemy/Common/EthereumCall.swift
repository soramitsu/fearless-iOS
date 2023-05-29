import Foundation
import IrohaCrypto

public class EthereumCall {
    public init() {}

    open var methodSignature: String {
        fatalError("Subclasses must override.")
    }

    open var arguments: [Any] {
        fatalError("Subclasses must override.")
    }

    public func signatureSHA3() throws -> Data {
        guard let signatureData = methodSignature.data(using: .ascii) else {
            throw ABIDecoderError.badSignature
        }

        return try signatureData.blake2b32()
    }
}
