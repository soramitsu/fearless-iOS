import XCTest
@testable import fearless
import SSFModels
import SSFStorageQueryKit

final class StorageRequestTests: XCTestCase {
    func testSimpleRequestsUseExpectedStoragePaths() {
        XCTAssertEqual(SystemNumberRequest().storagePath, .blockNumber)
        assertSimpleWorkerType(SystemNumberRequest().parametersType.workerType)

        XCTAssertEqual(StakingCurrentEraRequest().storagePath, .currentEra)
        assertSimpleWorkerType(StakingCurrentEraRequest().parametersType.workerType)
    }

    func testAccountBasedRequestsKeepAccountIdAndAddressVariants() {
        let accountId = Data(repeating: 0x01, count: 32)
        let address = "5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehHGKutQY"

        assertEncodable(
            StakingControllerRequest(accountId: .accountId(accountId)).parametersType,
            equals: accountId
        )
        assertEncodable(
            StakingControllerRequest(accountId: .address(address)).parametersType,
            equals: address
        )
        XCTAssertEqual(StakingControllerRequest(accountId: .accountId(accountId)).storagePath, .controller)

        assertEncodable(
            StakingLedgerRequest(accountId: .accountId(accountId)).parametersType,
            equals: accountId
        )
        assertEncodable(
            StakingLedgerRequest(accountId: .address(address)).parametersType,
            equals: address
        )
        XCTAssertEqual(StakingLedgerRequest(accountId: .accountId(accountId)).storagePath, .stakingLedger)

        assertEncodable(
            BalancesLocksRequest(accountId: .accountId(accountId)).parametersType,
            equals: accountId
        )
        assertEncodable(
            BalancesLocksRequest(accountId: .address(address)).parametersType,
            equals: address
        )
        XCTAssertEqual(BalancesLocksRequest(accountId: .accountId(accountId)).storagePath, .balanceLocks)
    }

    func testNominationPoolsMembersRequestUsesPoolMembersPath() {
        let accountId = Data(repeating: 0x02, count: 32)
        let request = NominationPoolsPoolMembersRequest(accountId: accountId)

        assertEncodable(request.parametersType, equals: accountId)
        XCTAssertEqual(request.storagePath, .stakingPoolMembers)
    }

    func testNMapRequestsPreserveExpectedKeyOrder() {
        let accountId = Data(repeating: 0x03, count: 32)
        let address = "15VjRaDX9zpbA8LVnbrCAFzrVxN7ixHNsCCHNRSPwY"
        let currencyId: SSFModels.CurrencyId = .assetId(id: "1984")

        let assetsByAccountId = AssetsAccountRequest(accountId: .accountId(accountId), currencyId: currencyId)
        let assetsByAddress = AssetsAccountRequest(accountId: .address(address), currencyId: currencyId)
        let tokensByAccountId = TokensLocksRequest(accountId: .accountId(accountId), currencyId: currencyId)
        let tokensByAddress = TokensLocksRequest(accountId: .address(address), currencyId: currencyId)

        assertNMap(assetsByAccountId.parametersType) { params in
            XCTAssertEqual(params.count, 2)
            XCTAssertCurrencyId(params[0][0], equals: currencyId)
            XCTAssertParam(params[1][0], equals: accountId)
        }
        XCTAssertEqual(assetsByAccountId.storagePath, .assetsAccount)

        assertNMap(assetsByAddress.parametersType) { params in
            XCTAssertEqual(params.count, 2)
            XCTAssertCurrencyId(params[0][0], equals: currencyId)
            XCTAssertParam(params[1][0], equals: address)
        }

        assertNMap(tokensByAccountId.parametersType) { params in
            XCTAssertEqual(params.count, 2)
            XCTAssertParam(params[0][0], equals: accountId)
            XCTAssertCurrencyId(params[1][0], equals: currencyId)
        }
        XCTAssertEqual(tokensByAccountId.storagePath, .tokensLocks)

        assertNMap(tokensByAddress.parametersType) { params in
            XCTAssertEqual(params.count, 2)
            XCTAssertParam(params[0][0], equals: address)
            XCTAssertCurrencyId(params[1][0], equals: currencyId)
        }
    }

    func testSystemAccountRequestSwitchesBetweenMapAndNMapAccess() {
        let accountId = Data(repeating: 0x04, count: 32)
        let address = "16ADqpMaowDqS9K5dPqA82nRp8fgfqqxY8P4x"

        let chain = ChainModelGenerator.generateChain(generatingAssets: 0, addressPrefix: 0)
        let plainAsset = ChainModelGenerator.generateAssetWithId("plain", symbol: "PLN")
        let utilityChainAsset = ChainAsset(chain: chain, asset: plainAsset)

        let plainRequest = SystemAccountRequest(accountId: .accountId(accountId), chainAsset: utilityChainAsset)
        assertEncodable(plainRequest.parametersType, equals: accountId)
        XCTAssertEqual(plainRequest.storagePath, .account)

        let addressRequest = SystemAccountRequest(accountId: .address(address), chainAsset: utilityChainAsset)
        assertEncodable(addressRequest.parametersType, equals: address)

        let assetWithCurrencyId = SSFModels.AssetModel(
            id: "asset-with-currency-id",
            name: "Asset",
            symbol: "AST",
            precision: 12,
            icon: nil,
            currencyId: "42",
            existentialDeposit: nil,
            color: nil,
            isUtility: false,
            isNative: false,
            staking: nil,
            purchaseProviders: nil,
            assetType: .substrate(substrateType: .assetId),
            priceProvider: nil,
            coingeckoPriceId: nil,
            priceData: []
        )
        let chainAsset = ChainAsset(chain: chain, asset: assetWithCurrencyId)

        let accountIdRequest = SystemAccountRequest(accountId: .accountId(accountId), chainAsset: chainAsset)
        assertNMap(accountIdRequest.parametersType) { params in
            XCTAssertEqual(params.count, 2)
            XCTAssertParam(params[0][0], equals: accountId)
            XCTAssertCurrencyId(params[1][0], equals: .assetId(id: "42"))
        }

        let addressNMapRequest = SystemAccountRequest(accountId: .address(address), chainAsset: chainAsset)
        assertNMap(addressNMapRequest.parametersType) { params in
            XCTAssertEqual(params.count, 2)
            XCTAssertParam(params[0][0], equals: address)
            XCTAssertCurrencyId(params[1][0], equals: .assetId(id: "42"))
        }
    }

    func testPrefixRequestsPointToExpectedStakingStorageEntries() {
        let rewardPoints = StakingErasRewardPointsRequest()
        assertStoragePath(
            rewardPoints.storagePath,
            equals: fearless.StorageCodingPath.erasRewardPoints
        )
        assertU32KeyType(rewardPoints.keyType)
        assertSimplePrefixParameters(rewardPoints.parametersType)

        let totalStake = StakingErasTotalStakeRequest()
        assertStoragePath(
            totalStake.storagePath,
            equals: fearless.StorageCodingPath.erasTotalStake
        )
        assertU32KeyType(totalStake.keyType)
        assertSimplePrefixParameters(totalStake.parametersType)

        let validatorReward = StakingErasValidatorRewardRequest()
        assertStoragePath(
            validatorReward.storagePath,
            equals: fearless.StorageCodingPath.erasValidatorReward
        )
        assertU32KeyType(validatorReward.keyType)
        assertSimplePrefixParameters(validatorReward.parametersType)
    }

    private func assertEncodable<T: Equatable & Encodable>(
        _ parametersType: fearless.StorageRequestParametersType,
        equals expected: T,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case let .encodable(param) = parametersType else {
            XCTFail("Expected encodable parameters", file: file, line: line)
            return
        }

        guard let value = param as? T else {
            XCTFail("Unexpected parameter type: \(type(of: param))", file: file, line: line)
            return
        }

        XCTAssertEqual(value, expected, file: file, line: line)
    }

    private func assertNMap(
        _ parametersType: fearless.StorageRequestParametersType,
        file: StaticString = #filePath,
        line: UInt = #line,
        assertions: ([[any fearless.NMapKeyParamProtocol]]) -> Void
    ) {
        guard case let .nMap(params) = parametersType else {
            XCTFail("Expected nMap parameters", file: file, line: line)
            return
        }

        assertions(params)
    }

    private func XCTAssertParam<T: Equatable & Encodable>(
        _ param: any fearless.NMapKeyParamProtocol,
        equals expected: T,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let typedParam = param as? fearless.NMapKeyParam<T> else {
            XCTFail("Unexpected key param type: \(type(of: param))", file: file, line: line)
            return
        }

        XCTAssertEqual(typedParam.value, expected, file: file, line: line)
    }

    private func XCTAssertCurrencyId(
        _ param: any fearless.NMapKeyParamProtocol,
        equals expected: SSFModels.CurrencyId,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let typedParam = param as? fearless.NMapKeyParam<SSFModels.CurrencyId> else {
            XCTFail("Unexpected currency param type: \(type(of: param))", file: file, line: line)
            return
        }

        switch (typedParam.value, expected) {
        case let (.assetId(id: lhs), .assetId(id: rhs)):
            XCTAssertEqual(lhs, rhs, file: file, line: line)
        default:
            XCTFail("Unexpected currency id values", file: file, line: line)
        }
    }

    private func assertSimpleWorkerType(
        _ workerType: fearless.StorageRequestWorkerType,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case .simple = workerType else {
            XCTFail("Expected simple worker type", file: file, line: line)
            return
        }
    }

    private func assertSimplePrefixParameters(
        _ parametersType: SSFStorageQueryKit.PrefixStorageRequestParametersType,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case .simple = parametersType else {
            XCTFail("Expected simple prefix parameters", file: file, line: line)
            return
        }
    }

    private func assertU32KeyType(
        _ keyType: SSFStorageQueryKit.MapKeyType,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case .u32 = keyType else {
            XCTFail("Expected u32 key type", file: file, line: line)
            return
        }
    }

    private func assertStoragePath(
        _ storagePath: any SSFModels.StorageCodingPathProtocol,
        equals expected: fearless.StorageCodingPath,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(storagePath.moduleName, expected.moduleName, file: file, line: line)
        XCTAssertEqual(storagePath.itemName, expected.itemName, file: file, line: line)
    }
}
