import CryptoKit
import Foundation

enum IrohaConnectAccountProviderError: LocalizedError, Equatable {
    case walletUnavailable
    case networkUnavailable
    case accountUnavailable
    case rootMaterialUnavailable
    case accountMismatch
    case signingFailed

    var errorDescription: String? {
        switch self {
        case .walletUnavailable:
            return "Select and unlock a wallet before connecting a SORA dApp."
        case .networkUnavailable:
            return "The Taira network is not ready yet. Try again after wallet setup finishes."
        case .accountUnavailable:
            return "The selected wallet does not have a usable Taira account."
        case .rootMaterialUnavailable:
            return "Fearless could not access this wallet's signing material."
        case .accountMismatch:
            return "The selected Taira account does not match this wallet's protected signing key."
        case .signingFailed:
            return "Fearless could not create the requested Iroha signature."
        }
    }
}

struct IrohaConnectAccountDescriptor: Equatable {
    let walletName: String
    let accountID: String
    let publicKey: Data
}

protocol IrohaConnectAccountProviding {
    func selectedAccount() throws -> IrohaConnectAccountDescriptor
    func sign(_ message: Data, for account: IrohaConnectAccountDescriptor) throws -> Data
}

final class KeychainIrohaConnectAccountProvider: IrohaConnectAccountProviding {
    private struct SigningMaterial {
        let descriptor: IrohaConnectAccountDescriptor
        var privateKey: Data
    }

    private let descriptorLoader: () throws -> IrohaConnectAccountDescriptor
    private let materialLoader: () throws -> (IrohaConnectAccountDescriptor, Data)

    init(materialLoader: @escaping () throws -> (IrohaConnectAccountDescriptor, Data)) {
        descriptorLoader = { try materialLoader().0 }
        self.materialLoader = materialLoader
    }

    init(
        descriptorLoader: @escaping () throws -> IrohaConnectAccountDescriptor,
        materialLoader: @escaping () throws -> (IrohaConnectAccountDescriptor, Data)
    ) {
        self.descriptorLoader = descriptorLoader
        self.materialLoader = materialLoader
    }

    convenience init() {
        self.init(
            descriptorLoader: Self.loadSelectedWalletDescriptor,
            materialLoader: Self.loadSelectedWalletMaterial
        )
    }

    func selectedAccount() throws -> IrohaConnectAccountDescriptor {
        try descriptorLoader()
    }

    func sign(_ message: Data, for account: IrohaConnectAccountDescriptor) throws -> Data {
        var material = try loadMaterial()
        defer { material.privateKey.resetBytes(in: 0 ..< material.privateKey.count) }

        guard material.descriptor == account else {
            throw IrohaConnectAccountProviderError.accountMismatch
        }

        do {
            let privateKey = try Curve25519.Signing.PrivateKey(rawRepresentation: material.privateKey)
            guard privateKey.publicKey.rawRepresentation == account.publicKey else {
                throw IrohaConnectAccountProviderError.accountMismatch
            }
            return try privateKey.signature(for: message)
        } catch let error as IrohaConnectAccountProviderError {
            throw error
        } catch {
            throw IrohaConnectAccountProviderError.signingFailed
        }
    }

    private func loadMaterial() throws -> SigningMaterial {
        let loaded = try materialLoader()
        guard loaded.0.publicKey.count == 32, loaded.1.count == 32 else {
            throw IrohaConnectAccountProviderError.signingFailed
        }

        // `CryptoKit` raw representations can alias their source key's backing
        // storage. Make a distinct allocation before zeroizing our working copy.
        let privateKey = loaded.1.withUnsafeBytes { bytes -> Data in
            guard let baseAddress = bytes.baseAddress else {
                return Data()
            }
            return Data(bytes: baseAddress, count: bytes.count)
        }
        return SigningMaterial(descriptor: loaded.0, privateKey: privateKey)
    }

    private static func loadSelectedWalletMaterial() throws -> (IrohaConnectAccountDescriptor, Data) {
        guard let wallet = SelectedWalletSettings.shared.value else {
            throw IrohaConnectAccountProviderError.walletUnavailable
        }

        let registry = ChainRegistryFacade.sharedRegistry
        guard let chain = registry.getChain(for: UniversalWalletRegistry.taira.chainId)
            ?? registry.getChain(for: UniversalWalletRegistry.taira.id) else {
            throw IrohaConnectAccountProviderError.networkUnavailable
        }
        guard let selectedAddress = UniversalWalletAccountAddressResolver.address(for: chain, wallet: wallet) else {
            throw IrohaConnectAccountProviderError.accountUnavailable
        }
        guard let mnemonic = try KeychainUniversalWalletMnemonicProvider().mnemonic(for: wallet, chain: chain) else {
            throw IrohaConnectAccountProviderError.rootMaterialUnavailable
        }

        let derived: IrohaDerivedAddress
        do {
            derived = try IrohaKeyDerivation.deriveAddress(
                mnemonic: mnemonic,
                chainDiscriminant: UniversalWalletRegistry.taira.chainDiscriminant
            )
        } catch {
            throw IrohaConnectAccountProviderError.rootMaterialUnavailable
        }

        guard let canonicalSelected = try? IrohaAddressCodec.parse(
            selectedAddress,
            expectedDiscriminant: UniversalWalletRegistry.taira.chainDiscriminant
        ).i105,
            canonicalSelected == derived.i105 else {
            throw IrohaConnectAccountProviderError.accountMismatch
        }

        return (
            IrohaConnectAccountDescriptor(
                walletName: wallet.name,
                accountID: derived.i105,
                publicKey: derived.account.publicKey
            ),
            derived.account.privateKey
        )
    }

    private static func loadSelectedWalletDescriptor() throws -> IrohaConnectAccountDescriptor {
        guard let wallet = SelectedWalletSettings.shared.value else {
            throw IrohaConnectAccountProviderError.walletUnavailable
        }

        let registry = ChainRegistryFacade.sharedRegistry
        guard let chain = registry.getChain(for: UniversalWalletRegistry.taira.chainId)
            ?? registry.getChain(for: UniversalWalletRegistry.taira.id) else {
            throw IrohaConnectAccountProviderError.networkUnavailable
        }
        guard let selectedAddress = UniversalWalletAccountAddressResolver.address(for: chain, wallet: wallet),
              let details = try? IrohaAddressCodec.parse(
                  selectedAddress,
                  expectedDiscriminant: UniversalWalletRegistry.taira.chainDiscriminant
              ),
              let publicKey = Data(irohaConnectHex: details.publicKeyHex),
              publicKey.count == 32 else {
            throw IrohaConnectAccountProviderError.accountUnavailable
        }

        return IrohaConnectAccountDescriptor(
            walletName: wallet.name,
            accountID: details.i105,
            publicKey: publicKey
        )
    }
}

private extension Data {
    init?(irohaConnectHex value: String) {
        guard value.count == 64 else {
            return nil
        }

        var bytes = [UInt8]()
        bytes.reserveCapacity(32)
        var index = value.startIndex
        while index < value.endIndex {
            let next = value.index(index, offsetBy: 2)
            guard let byte = UInt8(value[index ..< next], radix: 16) else {
                return nil
            }
            bytes.append(byte)
            index = next
        }
        self.init(bytes)
    }
}
