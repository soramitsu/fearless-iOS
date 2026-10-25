import BigInt
import Foundation
import IrohaCrypto

public struct JunctionResult {
    public let chaincodes: [Chaincode]
    public let password: String?

    public init(chaincodes: [Chaincode], password: String?) {
        self.chaincodes = chaincodes
        self.password = password
    }
}

public protocol JunctionFactoryProtocol {
    func parse(path: String) throws -> JunctionResult
}

public enum JunctionFactoryError: Error {
    case emptyPath
    case emptyPassphrase
    case multiplePassphrase
    case emptyJunction
    case invalidStart
}

public class JunctionFactory {
    static let passwordSeparator = "///"
    static let hardSeparator = "//"
    static let softSeparator = "/"

    private func parseChaincodesFromJunctionPath(_ junctionsPath: String) throws -> [Chaincode] {
        try junctionsPath
            .components(separatedBy: Self.hardSeparator)
            .map { component in

                var chaincodes: [Chaincode] = []

                let subcomponents = component.components(separatedBy: Self.softSeparator)

                guard let hardJunction = subcomponents.first else {
                    throw JunctionFactoryError.emptyJunction
                }

                if !hardJunction.isEmpty {
                    let hardChaincode = try createChaincodeFromJunction(hardJunction, type: .hard)
                    chaincodes.append(hardChaincode)
                }

                let softJunctions: [Chaincode] = try subcomponents[1...].map { junction in
                    try createChaincodeFromJunction(junction, type: .soft)
                }

                chaincodes.append(contentsOf: softJunctions)

                return chaincodes
            }.reduce([Chaincode]()) { result, chaincodes in
                result + chaincodes
            }
    }

    func createChaincodeFromJunction(_: String, type _: ChaincodeType) throws -> Chaincode {
        fatalError("This function should be overriden")
    }
}

extension JunctionFactory: JunctionFactoryProtocol {
    public func parse(path: String) throws -> JunctionResult {
        guard path.hasPrefix(Self.softSeparator) else {
            throw JunctionFactoryError.invalidStart
        }

        let passwordIncludedComponents = path.components(separatedBy: Self.passwordSeparator)

        guard let junctionsPath = passwordIncludedComponents.first else {
            throw JunctionFactoryError.emptyPath
        }

        guard passwordIncludedComponents.count <= 2 else {
            throw JunctionFactoryError.multiplePassphrase
        }

        let password: String?

        if passwordIncludedComponents.count == 2 {
            password = passwordIncludedComponents.last
        } else {
            password = nil
        }

        if let existingPassword = password, existingPassword.isEmpty {
            throw JunctionFactoryError.emptyPassphrase
        }

        let chaincodes = try parseChaincodesFromJunctionPath(junctionsPath)

        return JunctionResult(chaincodes: chaincodes, password: password)
    }
}
