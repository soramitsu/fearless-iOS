import XCTest
import RobinHood
import SoraKeystore
import SSFModels
@testable import fearless

final class CovHSendDependencyContainerTests: XCTestCase {
    private var storedTags: [String] = []

    override func tearDown() {
        let keychain = Keychain()
        storedTags.forEach { try? keychain.deleteKey(for: $0) }
        storedTags = []
        super.tearDown()
    }

    @MainActor
    func testSubstrateNetworkWithoutRuntimeIsRefused() async throws {
        let wallet = AccountGenerator.generateMetaAccount()
        let container = SendDepencyContainer(wallet: wallet, operationManager: OperationManager())
        let chainAsset = CovHSendFixtures.chainAsset(chainName: "Covh No Runtime", assetUtility: true)
        do {
            _ = try await container.prepareDepencies(chainAsset: chainAsset)
            XCTFail("A network without runtime metadata cannot send")
        } catch {
            guard case ChainRegistryError.runtimeMetadaUnavailable = error else {
                return XCTFail("Unexpected error \(error)")
            }
        }
    }

    @MainActor
    func testEthereumNetworkNeedsTheStoredKeyAndAConnection() async throws {
        let wallet = AccountGenerator.generateMetaAccount()
        let container = SendDepencyContainer(wallet: wallet, operationManager: OperationManager())
        let asset = CovHSendFixtures.asset(id: "eth", symbol: "ETH", utility: true, precision: 18)
        let chain = CovHSendFixtures.chain(name: "Covh EVM", assets: [asset], options: [.ethereum])
        let chainAsset = ChainAsset(chain: chain, asset: asset)
        do {
            _ = try await container.prepareDepencies(chainAsset: chainAsset)
            XCTFail("No secret key is stored for this wallet")
        } catch {
            XCTAssertFalse(error is UniversalWalletSendRoutingError)
        }

        let tag = fearless.KeystoreTagV2.ethereumSecretKeyTagForMetaId(wallet.metaId, accountId: nil)
        try Keychain().saveKey(Data(repeating: 1, count: 32), with: tag)
        storedTags.append(tag)
        do {
            _ = try await container.prepareDepencies(chainAsset: chainAsset)
            XCTFail("No node is connected for this network")
        } catch {
            guard case ChainRegistryError.connectionUnavailable = error else {
                return XCTFail("Unexpected error \(error)")
            }
        }
    }

    private static let mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"

    /// A wallet holding the Bitcoin and Solana chain accounts the universal send routes look up.
    private static func universalWallet(bitcoinChainId: String, solanaChainId: String) throws -> MetaAccountModel {
        let bitcoinAccount = try BitcoinKeyDerivation.deriveAccount(mnemonic: mnemonic)
        let solanaAccount = try SolanaKeyDerivation.deriveAccount(mnemonic: mnemonic)
        return AccountGenerator.generateMetaAccount(with: [
            ChainAccountModel(
                chainId: bitcoinChainId, accountId: bitcoinAccount.publicKey, publicKey: bitcoinAccount.publicKey,
                cryptoType: CryptoType.ecdsa.rawValue, ethereumBased: false
            ),
            ChainAccountModel(
                chainId: solanaChainId, accountId: solanaAccount.publicKey, publicKey: solanaAccount.publicKey,
                cryptoType: CryptoType.ed25519.rawValue, ethereumBased: false
            )
        ])
    }

    @MainActor
    func testUniversalNetworksFollowTheSendGateAndReuseTheirServices() async throws {
        let bitcoin = try CovHSendFixtures.bitcoin()
        let solana = try CovHSendFixtures.solana()
        let wallet = try Self.universalWallet(bitcoinChainId: bitcoin.chain.chainId, solanaChainId: solana.chain.chainId)
        let container = SendDepencyContainer(wallet: wallet, operationManager: OperationManager())
        let gate = UniversalSendGate.production

        guard gate.isEnabled(.solana) else {
            do {
                _ = try await container.prepareDepencies(chainAsset: solana)
                XCTFail("A vetoed Solana send must not be routed")
            } catch {
                XCTAssertEqual(error as? UniversalWalletSendRoutingError, .solanaSendPaused)
            }
            return
        }

        let solanaDependencies = try await container.prepareDepencies(chainAsset: solana)
        XCTAssertTrue(solanaDependencies.transferService is SolanaTransferService)
        XCTAssertEqual(solanaDependencies.chainAsset.chainAssetId, solana.chainAssetId)
        XCTAssertNil(solanaDependencies.equilibruimTotalBalanceService)
        XCTAssertNil(solanaDependencies.polkaswapService)

        guard gate.isEnabled(.bitcoin) else { return }
        let bitcoinDependencies = try await container.prepareDepencies(chainAsset: bitcoin)
        let solanaAgain = try await container.prepareDepencies(chainAsset: solana)
        XCTAssertTrue(bitcoinDependencies.transferService is BitcoinTransferService)
        XCTAssertTrue(
            (solanaAgain.transferService as AnyObject) === (solanaDependencies.transferService as AnyObject),
            "Switching back reuses the cached services"
        )
    }

    @MainActor
    func testIrohaSendsStayDisabled() async throws {
        let wallet = AccountGenerator.generateMetaAccount()
        let container = SendDepencyContainer(wallet: wallet, operationManager: OperationManager())
        let taira = try XCTUnwrap(UniversalWalletRegistry.tairaChainModel.chainAssets.first)
        do {
            _ = try await container.prepareDepencies(chainAsset: taira)
            XCTFail("Iroha sends are disabled in production")
        } catch {
            XCTAssertEqual(error as? UniversalWalletSendRoutingError, .irohaProductionSendDisabled)
        }
    }
}
