import Foundation
import FearlessUtils
import IrohaCrypto

struct MnemonicImportSecrets {
    let entropy: Data
    let derivationPath: String?
    let seed: Data
    let keypair: IRCryptoKeypairProtocol
}

protocol AccountImporting {
    func importEntropy(_ entropy: Data, derivationPath: String?) throws -> MnemonicImportSecrets
}

class EthereumAccountImportWrapper: AccountImporting {
    func importEntropy(_ entropy: Data, derivationPath: String?) throws -> MnemonicImportSecrets {
        let junctionResult: JunctionResult?

        if let derivationPath = derivationPath {
            let junctionFactory = BIP32JunctionFactory()
            junctionResult = try junctionFactory.parse(path: derivationPath)
        } else {
            junctionResult = nil
        }

        let mnemonic = try IRMnemonicCreator().mnemonic(fromEntropy: entropy)
        let seedFactory = BIP32SeedFactory(mnemonicLanguage: .english)
        let seedResult = try seedFactory.deriveSeed(
            from: mnemonic.toString(),
            password: junctionResult?.password ?? ""
        )

        let keypair = try BIP32KeypairFactory().createKeypairFromSeed(
            seedResult.seed,
            chaincodeList: junctionResult?.chaincodes ?? []
        )

        return MnemonicImportSecrets(
            entropy: entropy,
            derivationPath: derivationPath,
            seed: seedResult.seed,
            keypair: keypair
        )
    }
}
