import SSFCrypto
import SSFHelpers
import SSFModels
import SSFRuntimeCodingService
import SSFUtils
import Web3
import XCTest

@testable import SSFTransferService

final class SubstrateCallFactoryTests: XCTestCase {
    private var callFactory: SubstrateTransferCallFactory?

    override func setUp() async throws {
        try await super.setUp()
        try await setupCallFactory()
    }

    func testSoraNormalTransfer() throws {
        let chainAsset = createChainAsset(
            chain: .soraMain,
            substrateAssetType: .normal,
            currencyId: nil
        )
        let accountId = generateAccountId(for: chainAsset.chain)
        let call = callFactory?.transfer(to: accountId, amount: .zero, chainAsset: chainAsset)
        let expectedArgs = TransferCall(dest: .accoundId(accountId), value: .zero, currencyId: nil)
        let args = try extractArgs(from: call)

        XCTAssertEqual(args, expectedArgs)
        XCTAssertEqual(call?.callName, SubstrateCallPath.assetsTransfer.callName)
        XCTAssertEqual(call?.moduleName, SubstrateCallPath.assetsTransfer.moduleName)
    }

    func testReefNormalTransfer() throws {
        let chainAsset = createChainAsset(
            chain: .reef,
            substrateAssetType: .normal,
            currencyId: nil
        )
        let accountId = generateAccountId(for: chainAsset.chain)
        let call = callFactory?.transfer(to: accountId, amount: .zero, chainAsset: chainAsset)
        let expectedArgs = TransferCall(
            dest: .indexedString(accountId),
            value: .zero,
            currencyId: nil
        )
        let args = try extractArgs(from: call)

        XCTAssertEqual(args, expectedArgs)
        XCTAssertEqual(call?.callName, SubstrateCallPath.defaultTransfer.callName)
        XCTAssertEqual(call?.moduleName, SubstrateCallPath.defaultTransfer.moduleName)
    }

    func testDefaultTransfer() throws {
        let chainAsset = createChainAsset(
            chain: .polkadot,
            substrateAssetType: .normal,
            currencyId: nil
        )
        let accountId = generateAccountId(for: chainAsset.chain)
        let call = callFactory?.transfer(to: accountId, amount: .zero, chainAsset: chainAsset)
        let expectedArgs = TransferCall(dest: .accoundId(accountId), value: .zero, currencyId: nil)
        let args = try extractArgs(from: call)

        XCTAssertEqual(args, expectedArgs)
        XCTAssertEqual(call?.callName, SubstrateCallPath.transferAllowDeath.callName)
        XCTAssertEqual(call?.moduleName, SubstrateCallPath.transferAllowDeath.moduleName)
    }

    func testOrmlChainTransfer() throws {
        let chainAsset = createChainAsset(
            chain: .kusama,
            substrateAssetType: .ormlChain,
            currencyId: nil
        )
        let accountId = generateAccountId(for: chainAsset.chain)
        let call = callFactory?.transfer(to: accountId, amount: .zero, chainAsset: chainAsset)
        let expectedArgs = TransferCall(
            dest: .accoundId(accountId),
            value: .zero,
            currencyId: .ormlAsset(symbol: .init(symbol: "ksm"))
        )
        let args = try extractArgs(from: call)

        XCTAssertEqual(args, expectedArgs)
        XCTAssertEqual(call?.callName, SubstrateCallPath.ormlChainTransfer.callName)
        XCTAssertEqual(call?.moduleName, SubstrateCallPath.ormlChainTransfer.moduleName)
    }

    func testOrmlAssetTransfer() throws {
        let chainAsset = createChainAsset(
            chain: .kusama,
            substrateAssetType: .ormlAsset,
            currencyId: "1"
        )
        let accountId = generateAccountId(for: chainAsset.chain)
        let call = callFactory?.transfer(to: accountId, amount: .zero, chainAsset: chainAsset)
        let expectedArgs = TransferCall(
            dest: .accoundId(accountId),
            value: .zero,
            currencyId: .ormlAsset(symbol: .init(symbol: "1"))
        )
        let args = try extractArgs(from: call)

        XCTAssertEqual(args, expectedArgs)
        XCTAssertEqual(call?.callName, SubstrateCallPath.ormlAssetTransfer.callName)
        XCTAssertEqual(call?.moduleName, SubstrateCallPath.ormlAssetTransfer.moduleName)
    }

    func testForeignAssetTransfer() throws {
        let chainAsset = createChainAsset(
            chain: .kusama,
            substrateAssetType: .foreignAsset,
            currencyId: "1"
        )
        let accountId = generateAccountId(for: chainAsset.chain)
        let call = callFactory?.transfer(to: accountId, amount: .zero, chainAsset: chainAsset)
        let expectedArgs = TransferCall(
            dest: .accoundId(accountId),
            value: .zero,
            currencyId: .foreignAsset(foreignAsset: "1")
        )
        let args = try extractArgs(from: call)

        XCTAssertEqual(args, expectedArgs)
        XCTAssertEqual(call?.callName, SubstrateCallPath.ormlAssetTransfer.callName)
        XCTAssertEqual(call?.moduleName, SubstrateCallPath.ormlAssetTransfer.moduleName)
    }

    func testStableAssetPoolTokenTransfer() throws {
        let chainAsset = createChainAsset(
            chain: .kusama,
            substrateAssetType: .stableAssetPoolToken,
            currencyId: "1"
        )
        let accountId = generateAccountId(for: chainAsset.chain)
        let call = callFactory?.transfer(to: accountId, amount: .zero, chainAsset: chainAsset)
        let expectedArgs = TransferCall(
            dest: .accoundId(accountId),
            value: .zero,
            currencyId: .stableAssetPoolToken(stableAssetPoolToken: "1")
        )
        let args = try extractArgs(from: call)

        XCTAssertEqual(args, expectedArgs)
        XCTAssertEqual(call?.callName, SubstrateCallPath.ormlAssetTransfer.callName)
        XCTAssertEqual(call?.moduleName, SubstrateCallPath.ormlAssetTransfer.moduleName)
    }

    func testLiquidCrowdloanAssetTransfer() throws {
        let chainAsset = createChainAsset(
            chain: .kusama,
            substrateAssetType: .liquidCrowdloan,
            currencyId: "1"
        )
        let accountId = generateAccountId(for: chainAsset.chain)
        let call = callFactory?.transfer(to: accountId, amount: .zero, chainAsset: chainAsset)
        let expectedArgs = TransferCall(
            dest: .accoundId(accountId),
            value: .zero,
            currencyId: .liquidCrowdloan(liquidCrowdloan: "1")
        )
        let args = try extractArgs(from: call)

        XCTAssertEqual(args, expectedArgs)
        XCTAssertEqual(call?.callName, SubstrateCallPath.ormlAssetTransfer.callName)
        XCTAssertEqual(call?.moduleName, SubstrateCallPath.ormlAssetTransfer.moduleName)
    }

    func testVTokenTransfer() throws {
        let chainAsset = createChainAsset(
            chain: .kusama,
            substrateAssetType: .vToken,
            currencyId: "1"
        )
        let accountId = generateAccountId(for: chainAsset.chain)
        let call = callFactory?.transfer(to: accountId, amount: .zero, chainAsset: chainAsset)
        let expectedArgs = TransferCall(
            dest: .accoundId(accountId),
            value: .zero,
            currencyId: .vToken(symbol: .init(symbol: "1"))
        )
        let args = try extractArgs(from: call)

        XCTAssertEqual(args, expectedArgs)
        XCTAssertEqual(call?.callName, SubstrateCallPath.ormlAssetTransfer.callName)
        XCTAssertEqual(call?.moduleName, SubstrateCallPath.ormlAssetTransfer.moduleName)
    }

    func testVsTokenTransfer() throws {
        let chainAsset = createChainAsset(
            chain: .kusama,
            substrateAssetType: .vsToken,
            currencyId: "1"
        )
        let accountId = generateAccountId(for: chainAsset.chain)
        let call = callFactory?.transfer(to: accountId, amount: .zero, chainAsset: chainAsset)
        let expectedArgs = TransferCall(
            dest: .accoundId(accountId),
            value: .zero,
            currencyId: .vsToken(symbol: .init(symbol: "1"))
        )
        let args = try extractArgs(from: call)

        XCTAssertEqual(args, expectedArgs)
        XCTAssertEqual(call?.callName, SubstrateCallPath.ormlAssetTransfer.callName)
        XCTAssertEqual(call?.moduleName, SubstrateCallPath.ormlAssetTransfer.moduleName)
    }

    func testStableTokenTransfer() throws {
        let chainAsset = createChainAsset(
            chain: .kusama,
            substrateAssetType: .stable,
            currencyId: "1"
        )
        let accountId = generateAccountId(for: chainAsset.chain)
        let call = callFactory?.transfer(to: accountId, amount: .zero, chainAsset: chainAsset)
        let expectedArgs = TransferCall(
            dest: .accoundId(accountId),
            value: .zero,
            currencyId: .stable(symbol: .init(symbol: "1"))
        )
        let args = try extractArgs(from: call)

        XCTAssertEqual(args, expectedArgs)
        XCTAssertEqual(call?.callName, SubstrateCallPath.ormlAssetTransfer.callName)
        XCTAssertEqual(call?.moduleName, SubstrateCallPath.ormlAssetTransfer.moduleName)
    }

    func testAssetIdTransfer() throws {
        let chainAsset = createChainAsset(
            chain: .kusama,
            substrateAssetType: .assetId,
            currencyId: "1"
        )
        let accountId = generateAccountId(for: chainAsset.chain)
        let call = callFactory?.transfer(to: accountId, amount: .zero, chainAsset: chainAsset)
        let expectedArgs = TransferCall(
            dest: .accoundId(accountId),
            value: .zero,
            currencyId: .assetId(id: "1")
        )
        let args = try extractArgs(from: call)

        XCTAssertEqual(args, expectedArgs)
        XCTAssertEqual(call?.callName, SubstrateCallPath.ormlAssetTransfer.callName)
        XCTAssertEqual(call?.moduleName, SubstrateCallPath.ormlAssetTransfer.moduleName)
    }

    func testToken2Transfer() throws {
        let chainAsset = createChainAsset(chain: .kusama, substrateAssetType: .xcm, currencyId: "1")
        let accountId = generateAccountId(for: chainAsset.chain)
        let call = callFactory?.transfer(to: accountId, amount: .zero, chainAsset: chainAsset)
        let expectedArgs = TransferCall(
            dest: .accoundId(accountId),
            value: .zero,
            currencyId: .xcm(id: "1")
        )
        let args = try extractArgs(from: call)

        XCTAssertEqual(args, expectedArgs)
        XCTAssertEqual(call?.callName, SubstrateCallPath.ormlAssetTransfer.callName)
        XCTAssertEqual(call?.moduleName, SubstrateCallPath.ormlAssetTransfer.moduleName)
    }

    func testXcmTokenTransfer() throws {
        let chainAsset = createChainAsset(
            chain: .kusama,
            substrateAssetType: .token2,
            currencyId: "1"
        )
        let accountId = generateAccountId(for: chainAsset.chain)
        let call = callFactory?.transfer(to: accountId, amount: .zero, chainAsset: chainAsset)
        let expectedArgs = TransferCall(
            dest: .accoundId(accountId),
            value: .zero,
            currencyId: .token2(id: "1")
        )
        let args = try extractArgs(from: call)

        XCTAssertEqual(args, expectedArgs)
        XCTAssertEqual(call?.callName, SubstrateCallPath.ormlAssetTransfer.callName)
        XCTAssertEqual(call?.moduleName, SubstrateCallPath.ormlAssetTransfer.moduleName)
    }

    func testEquilibriumTokenTransfer() throws {
        let chainAsset = createChainAsset(
            chain: .equilibrium,
            substrateAssetType: .equilibrium,
            currencyId: "1"
        )
        let accountId = generateAccountId(for: chainAsset.chain)
        let call = callFactory?.transfer(to: accountId, amount: .zero, chainAsset: chainAsset)
        let expectedArgs = TransferCall(
            dest: .accountTo(accountId),
            value: .zero,
            currencyId: .equilibrium(id: "1")
        )
        let args = try extractArgs(from: call)

        XCTAssertEqual(args, expectedArgs)
        XCTAssertEqual(call?.callName, SubstrateCallPath.equilibriumAssetTransfer.callName)
        XCTAssertEqual(call?.moduleName, SubstrateCallPath.equilibriumAssetTransfer.moduleName)
    }

    func testSoraAssetTransfer() throws {
        let chainAsset = createChainAsset(
            chain: .soraMain,
            substrateAssetType: .soraAsset,
            currencyId: "1"
        )
        let accountId = generateAccountId(for: chainAsset.chain)
        let call = callFactory?.transfer(to: accountId, amount: .zero, chainAsset: chainAsset)
        let expectedArgs = TransferCall(
            dest: .accoundId(accountId),
            value: .zero,
            currencyId: .soraAsset(id: "1")
        )
        let args = try extractArgs(from: call)

        XCTAssertEqual(args, expectedArgs)
        XCTAssertEqual(call?.callName, SubstrateCallPath.assetsTransfer.callName)
        XCTAssertEqual(call?.moduleName, SubstrateCallPath.assetsTransfer.moduleName)
    }

    func testAssetsTransfer() throws {
        let chainAsset = createChainAsset(
            chain: .soraMain,
            substrateAssetType: .assets,
            currencyId: "1"
        )
        let accountId = generateAccountId(for: chainAsset.chain)
        let call = callFactory?.transfer(to: accountId, amount: .zero, chainAsset: chainAsset)
        let expectedArgs = TransferCall(
            dest: .accoundId(accountId),
            value: .zero,
            currencyId: .assets(id: "1")
        )
        let args = try extractArgs(from: call)

        XCTAssertEqual(args, expectedArgs)
        XCTAssertEqual(call?.callName, SubstrateCallPath.assetsTransfer.callName)
        XCTAssertEqual(call?.moduleName, SubstrateCallPath.assetsTransfer.moduleName)
    }

    func testAssetsEthrereumBasedTransfer() throws {
        let chainAsset = createChainAsset(
            chain: .moonbeam,
            substrateAssetType: .assets,
            currencyId: "1"
        )
        let accountId = generateAccountId(for: chainAsset.chain)
        let call = callFactory?.transfer(to: accountId, amount: .zero, chainAsset: chainAsset)
        let expectedArgs = TransferCall(
            dest: .accountTo(accountId),
            value: .zero,
            currencyId: .assets(id: "1")
        )
        let args = try extractArgs(from: call)

        XCTAssertEqual(args, expectedArgs)
        XCTAssertEqual(call?.callName, SubstrateCallPath.assetsTransfer.callName)
        XCTAssertEqual(call?.moduleName, SubstrateCallPath.assetsTransfer.moduleName)
    }

    // MARK: - Private methods

    private func extractArgs(from call: (any RuntimeCallable)?) throws -> TransferCall {
        guard let args = call?.args as? TransferCall else {
            throw SubstrateCallFactoryTestsError.error(reason: "args has wrong type")
        }
        return args
    }

    private func generateAccountId(for chain: ChainModel) -> AccountId {
        let chainFormate: SFChainFormat = chain
            .isEthereumBased ? .sfEthereum : .sfSubstrate(chain.addressPrefix)
        let accountId = AddressFactory.randomAccountId(for: chainFormate)
        return accountId
    }

    private func setupCallFactory() async throws {
        guard callFactory == nil else {
            return
        }
        let operationQueue = OperationQueue()
        operationQueue.qualityOfService = .userInitiated
        let chainMetadata = try RuntimeMetadataItem(
            chain: "91b171bb158e2d3848fa23a9f1c25182fb8e20313b2c1eb49219da7a70ce90c3",
            version: 1,
            txVersion: 1,
            metadata: extractMetadata()
        )
        let runtimeService = try RuntimeProvider(
            operationQueue: operationQueue,
            usedRuntimePaths: [:],
            chainMetadata: chainMetadata,
            chainTypes: extractTypes()
        )
        let _ = try await runtimeService.readySnapshot()

        let callFactory = SubstrateTransferCallFactoryDefault(runtimeService: runtimeService)
        self.callFactory = callFactory
    }

    private func extractMetadata() throws -> Data {
        guard let url = Bundle.module.url(forResource: "polkadot-v14-metadata", withExtension: "") else {
            throw SubstrateCallFactoryTestsError.error(reason: "Can't find metadata file")
        }

        let hex = try String(contentsOf: url)
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        let expectedData = try Data(hexStringSSF: hex)
        return expectedData
    }

    private func extractTypes() throws -> Data {
        guard let url = Bundle.module.url(forResource: "types", withExtension: "json") else {
            throw SubstrateCallFactoryTestsError.error(reason: "Can't find metadata file")
        }
        let chainsData = try Data(contentsOf: url)
        return chainsData
    }

    private func createChainAsset(
        chain: Chain,
        substrateAssetType: SubstrateAssetType,
        currencyId: String?
    ) -> ChainAsset {
        let chainModel = ChainModelGenerator.generate(
            name: chain.rawValue,
            chainId: chain.genesisHash,
            count: 1,
            isEthereumBased: chain == .moonbeam
        ).first!
        let assetModel = ChainModelGenerator.generateAssetWithId(
            "1",
            symbol: "ksm",
            substrateAssetType: substrateAssetType,
            currencyId: currencyId
        )
        let chainAsset = ChainAsset(chain: chainModel, asset: assetModel)
        return chainAsset
    }

    enum SubstrateCallFactoryTestsError: Error {
        case error(reason: String)
    }
}
