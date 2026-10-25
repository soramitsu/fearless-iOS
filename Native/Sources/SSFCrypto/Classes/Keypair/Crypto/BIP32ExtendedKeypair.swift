import IrohaCrypto

public class BIP32ExtendedKeypair {
    let chaincode: Data
    let keypair: IRCryptoKeypairProtocol

    init(
        keypair: IRCryptoKeypairProtocol,
        chaincode: Data
    ) {
        self.keypair = keypair
        self.chaincode = chaincode
    }
}

extension BIP32ExtendedKeypair: IRCryptoKeypairProtocol {
    public func publicKey() -> IRPublicKeyProtocol {
        keypair.publicKey()
    }

    public func privateKey() -> IRPrivateKeyProtocol {
        keypair.privateKey()
    }
}
