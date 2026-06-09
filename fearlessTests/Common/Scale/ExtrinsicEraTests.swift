import XCTest
@testable import fearless
import BigInt
import struct RobinHood.StreamableProviderObserverOptions
import SSFModels
import SSFUtils

class ExtrinsicEraTests: XCTestCase {
    func testMortalEraDecoding() throws {
        // given

        let data = Data([78, 156])

        let scaleDecoder = try ScaleDecoder(data: data)

        // when

        let era = try Era(scaleDecoder: scaleDecoder)

        // then

        switch era {
        case .immortal:
            XCTFail("Mortal era expected")
        case let .mortal(period, phase):
            XCTAssertEqual(period, 32768)
            XCTAssertEqual(phase, 20000)
        }
    }

    func testImmortalEraDecoding() throws {
        // given

        let data = Data([0])

        let scaleDecoder = try ScaleDecoder(data: data)

        // when

        let era = try Era(scaleDecoder: scaleDecoder)

        // then

        switch era {
        case .immortal:
            break
        case .mortal:
            XCTFail("Immortal era expected")
        }
    }

    func testScaleEncodableExtension_whenEncodingImmortalEra_thenReturnsScaleBytes() throws {
        XCTAssertEqual(try Era.immortal.scaleEncoded(), Data([0]))
    }

    func testImmortalEraOperationFactory_whenCreated_thenReturnsImmortalParameters() throws {
        let factory = ImmortalEraOperationFactory()
        let wrapper = factory.createOperation(
            from: MockConnection(),
            runtimeService: try RuntimeCodingServiceStub.createWestendService()
        )
        let queue = OperationQueue()

        queue.addOperations(wrapper.allOperations, waitUntilFinished: true)

        let parameters: ExtrinsicEraParameters = try wrapper.targetOperation.extractNoCancellableResultData()
        XCTAssertEqual(parameters.blockNumber, 0)
        guard case .immortal = parameters.extrinsicEra else {
            return XCTFail("Immortal era expected")
        }
    }

    func testEventRecord_whenApplyExtrinsicPhaseDecoded_thenExposesExtrinsicIndexAndEventPayload() throws {
        let json = """
        {
          "phase": ["ApplyExtrinsic", "12"],
          "event": [
            "balances",
            [
              "Transfer",
              {
                "from": "alice",
                "to": "bob",
                "amount": 100
              }
            ]
          ]
        }
        """

        let record = try decode(EventRecord.self, from: json)

        XCTAssertEqual(record.extrinsicIndex, 12)
        XCTAssertEqual(record.event.section, "balances")
        XCTAssertEqual(record.event.method, "Transfer")
        XCTAssertEqual(record.event.data["from"]?.stringValue, "alice")
        XCTAssertEqual(record.event.data["amount"]?.unsignedIntValue, 100)
    }

    func testEventRecord_whenNonExtrinsicPhasesDecoded_thenExtrinsicIndexIsNil() throws {
        let finalization = try decode(EventRecord.self, from: eventRecordJson(phase: "Finalization"))
        let initialization = try decode(EventRecord.self, from: eventRecordJson(phase: "Initialization"))

        XCTAssertNil(finalization.extrinsicIndex)
        XCTAssertNil(initialization.extrinsicIndex)
    }

    func testEventRecord_whenUnknownPhaseDecoded_thenThrows() {
        XCTAssertThrowsError(try decode(EventRecord.self, from: eventRecordJson(phase: "Unknown")))
    }

    func testExtrinsicStatus_whenDecodedFromSupportedShapes_thenMapsStatusValues() throws {
        guard case .ready = try decode(ExtrinsicStatus.self, from: #""ready""#) else {
            return XCTFail("Ready status expected")
        }

        guard case .ready = try decode(ExtrinsicStatus.self, from: #"{"ready": null}"#) else {
            return XCTFail("Ready object status expected")
        }

        guard case let .broadcast(peers) = try decode(
            ExtrinsicStatus.self,
            from: #"{"broadcast": ["peer-a", "peer-b"]}"#
        ) else {
            return XCTFail("Broadcast status expected")
        }
        XCTAssertEqual(peers, ["peer-a", "peer-b"])

        guard case let .inBlock(blockHash) = try decode(
            ExtrinsicStatus.self,
            from: #"{"inBlock": "0xabc"}"#
        ) else {
            return XCTFail("In-block status expected")
        }
        XCTAssertEqual(blockHash, "0xabc")

        guard case let .finalized(blockHash) = try decode(
            ExtrinsicStatus.self,
            from: #"{"finalized": "0xdef"}"#
        ) else {
            return XCTFail("Finalized status expected")
        }
        XCTAssertEqual(blockHash, "0xdef")
    }

    func testExtrinsicStatus_whenDecodedFromMalformedStatus_thenThrows() {
        XCTAssertThrowsError(try decode(ExtrinsicStatus.self, from: #""broadcast""#))
        XCTAssertThrowsError(try decode(ExtrinsicStatus.self, from: #"{"broadcast": "peer-a"}"#))
        XCTAssertThrowsError(try decode(ExtrinsicStatus.self, from: #"{"unknown": null}"#))
    }

    func testDataStorageKey_whenAccountIdLengthProvided_thenReturnsSuffix() {
        let storageKey = Data([0, 1, 2, 3, 4, 5])

        XCTAssertEqual(storageKey.getAccountIdFromKey(accountIdLenght: 3), Data([3, 4, 5]))
        XCTAssertEqual(storageKey.getAccountIdFromKey(accountIdLenght: storageKey.count), storageKey)
        XCTAssertEqual(storageKey.getAccountIdFromKey(accountIdLenght: 0), Data())
    }

    func testStreamableProviderOptions_whenSubstrateSourceCreated_thenUsesExpectedDefaults() {
        let options = StreamableProviderObserverOptions.substrateSource(for: 7)

        XCTAssertFalse(options.alwaysNotifyOnRefresh)
        XCTAssertFalse(options.waitsInProgressSyncOnAdd)
        XCTAssertEqual(options.initialSize, 7)
        XCTAssertFalse(options.refreshWhenEmpty)
    }

    func testChainDataValues_whenReadingRawHashAndEmptyCases_thenReturnExpectedRepresentations() {
        let raw = Data("SORA".utf8)
        let hashData = Data(repeating: 0xAB, count: H256.length)
        let hash = H256(value: hashData)

        XCTAssertNil(ChainData.none.stringValue)
        XCTAssertNil(ChainData.none.dataValue)
        XCTAssertNil(ChainData.none.imageValue)

        XCTAssertEqual(ChainData.raw(data: raw).stringValue, "SORA")
        XCTAssertEqual(ChainData.raw(data: raw).dataValue, raw)
        XCTAssertNil(ChainData.raw(data: raw).imageValue)

        XCTAssertEqual(ChainData.blakeTwo256(data: hash).stringValue, "0x" + String(repeating: "ab", count: 32))
        XCTAssertEqual(ChainData.keccak256(data: hash).dataValue, hashData)
        XCTAssertEqual(ChainData.sha256(data: hash).stringValue, "0x" + String(repeating: "ab", count: 32))
        XCTAssertEqual(ChainData.shaThree256(data: hash).dataValue, hashData)
        XCTAssertNil(ChainData.shaThree256(data: hash).imageValue)
    }

    func testAssetDetails_whenDecodedFromV1AndV2Payloads_thenMapsStatusAndBalances() throws {
        let liveV2 = try decode(
            AssetDetails.self,
            from: #"{"minBalance":"10","status":["Live"],"isSufficient":true}"#
        )

        XCTAssertEqual(liveV2.minBalance, BigUInt(10))
        XCTAssertEqual(liveV2.status, .live)
        XCTAssertTrue(liveV2.isSufficient)
        XCTAssertFalse(liveV2.isFrozen)

        let frozenV1 = try decode(
            AssetDetails.self,
            from: #"{"minBalance":"25","isFrozen":true,"isSufficient":false}"#
        )

        XCTAssertEqual(frozenV1.minBalance, BigUInt(25))
        XCTAssertEqual(frozenV1.status, .frozen)
        XCTAssertFalse(frozenV1.isSufficient)
        XCTAssertTrue(frozenV1.isFrozen)

        XCTAssertThrowsError(
            try decode(AssetDetailsV2.Status.self, from: #"["Unknown"]"#)
        )
    }

    func testAssetAccountInfo_whenDecodedWithEachStatus_thenDerivesLockAmounts() throws {
        let liquid = try decode(AssetAccountInfo.self, from: assetAccountInfoJson(status: "Liquid"))
        XCTAssertEqual(liquid.balance, BigUInt(42))
        XCTAssertEqual(liquid.locked, BigUInt.zero)
        XCTAssertEqual(liquid.frozen, BigUInt.zero)
        XCTAssertEqual(liquid.blocked, BigUInt.zero)

        let frozen = try decode(AssetAccountInfo.self, from: assetAccountInfoJson(status: "Frozen"))
        XCTAssertEqual(frozen.locked, BigUInt(42))
        XCTAssertEqual(frozen.frozen, BigUInt(42))
        XCTAssertEqual(frozen.blocked, BigUInt.zero)

        let blocked = try decode(AssetAccountInfo.self, from: assetAccountInfoJson(status: "Blocked"))
        XCTAssertEqual(blocked.locked, BigUInt(42))
        XCTAssertEqual(blocked.frozen, BigUInt.zero)
        XCTAssertEqual(blocked.blocked, BigUInt(42))

        XCTAssertThrowsError(try decode(AssetAccountInfo.self, from: assetAccountInfoJson(status: "Unknown")))
    }

    func testMultiSigner_whenEncodedDecoded_thenRoundTripsSupportedVariants() throws {
        let signers: [MultiSigner] = [
            .ed25519(Data([1, 2, 3])),
            .sr25519(Data([4, 5, 6])),
            .ecdsa(Data([7, 8, 9]))
        ]

        for signer in signers {
            let encoded = try JSONEncoder().encode(signer)
            let decoded = try JSONDecoder().decode(MultiSigner.self, from: encoded)

            XCTAssertEqual(decoded, signer)
        }

        XCTAssertThrowsError(
            try decode(MultiSigner.self, from: #"["Unknown",["1","2","3"]]"#)
        )
    }

    func testTreasuryDepositEvent_whenDecodedFromScaleMappedString_thenReadsAmount() throws {
        let event = try decode(TreasuryDepositEvent.self, from: #"["123456789"]"#)

        XCTAssertEqual(event.amount, BigUInt(123_456_789))
    }

    func testRewardDestinationArg_whenEncodedDecoded_thenMapsSupportedCases() throws {
        let accountId = Data([1, 2, 3, 4])

        XCTAssertEqual(try decode(RewardDestinationArg.self, from: #"["Staked",null]"#), .staked)
        XCTAssertEqual(try decode(RewardDestinationArg.self, from: #"["Stash",null]"#), .stash)
        XCTAssertEqual(try decode(RewardDestinationArg.self, from: #"["Controller",null]"#), .controller)
        XCTAssertEqual(try decode(RewardDestinationArg.self, from: #"["Account","0x01020304"]"#), .account(accountId))
        XCTAssertThrowsError(try decode(RewardDestinationArg.self, from: #"["Unknown",null]"#))

        XCTAssertEqual(try jsonArray(from: RewardDestinationArg.staked)[0] as? String, "Staked")
        XCTAssertEqual(try jsonArray(from: RewardDestinationArg.stash)[0] as? String, "Stash")
        XCTAssertEqual(try jsonArray(from: RewardDestinationArg.controller)[0] as? String, "Controller")
        XCTAssertEqual(try jsonArray(from: RewardDestinationArg.account(accountId))[0] as? String, "Account")

        let addressPayload = try jsonArray(from: RewardDestinationArg.address("0xabc"))
        XCTAssertEqual(addressPayload[0] as? String, "Account")
        XCTAssertEqual(addressPayload[1] as? String, "0xabc")
    }

    func testCallArguments_whenEncoded_thenUseRuntimeCompatibleShapes() throws {
        let accountId = Data(repeating: 0x11, count: 32)
        let bondCall = BondCall(
            controller: .accoundId(accountId),
            value: BigUInt(100),
            payee: .account(Data([1, 2, 3]))
        )
        let bondObject = try jsonDictionary(from: bondCall)

        XCTAssertEqual(bondObject["value"] as? String, "100")
        XCTAssertEqual((bondObject["payee"] as? [Any])?.first as? String, "Account")
        XCTAssertEqual((bondObject["controller"] as? [Any])?.first as? String, "Id")

        let controllerlessBondCall = BondCall(controller: nil, value: BigUInt(50), payee: .staked)
        let controllerlessBondObject = try jsonDictionary(from: controllerlessBondCall)
        XCTAssertNil(controllerlessBondObject["controller"])
        XCTAssertEqual(controllerlessBondObject["value"] as? String, "50")

        let poolBondMore = PoolBondMoreCall(extra: .freeBalance(amount: BigUInt(200)))
        let poolBondMoreObject = try jsonDictionary(from: poolBondMore)
        let extra = try XCTUnwrap(poolBondMoreObject["extra"] as? [Any])
        XCTAssertEqual(extra[0] as? String, "FreeBalance")
        XCTAssertEqual(extra[1] as? String, "200")

        let rewardsBondMore = PoolBondMoreCall(extra: .rewards(amount: BigUInt(300)))
        let rewardsExtra = try XCTUnwrap(jsonDictionary(from: rewardsBondMore)["extra"] as? [Any])
        XCTAssertEqual(rewardsExtra[0] as? String, "Rewards")
        XCTAssertEqual(rewardsExtra[1] as? String, "300")

        let updateRoles = NominationPoolsUpdateRolesCall(
            poolId: "5",
            newRoot: .set(accountId),
            newNominator: .remove,
            newBouncer: nil
        )
        let updateRolesObject = try jsonDictionary(from: updateRoles)

        XCTAssertEqual(updateRolesObject["poolId"] as? String, "5")
        XCTAssertEqual((updateRolesObject["newRoot"] as? [Any])?.first as? String, "Set")
        XCTAssertEqual((updateRolesObject["newNominator"] as? [Any])?.first as? String, "Remove")
        XCTAssertNil(updateRolesObject["newBouncer"])

        let symbolPayload = try jsonArray(from: fearless.TokenSymbol(symbol: "xor"))
        XCTAssertEqual(symbolPayload[0] as? String, "XOR")
        XCTAssertTrue(symbolPayload[1] is NSNull)
    }

    func testTransferCall_whenEncodedDecoded_thenMapsCurrencySpecificShapes() throws {
        let plainTransfer = TransferCall(dest: .rawString(Data([1, 2])), value: BigUInt(10), currencyId: nil)
        let plainObject = try jsonDictionary(from: plainTransfer)

        XCTAssertEqual(plainObject["dest"] as? String, "0x0102")
        XCTAssertEqual(plainObject["value"] as? String, "10")

        let decodedPlain = try decode(TransferCall.self, from: #"{"dest":["Raw","AQI="],"value":"99"}"#)
        XCTAssertEqual(decodedPlain.dest, .raw(Data([1, 2])))
        XCTAssertEqual(decodedPlain.value, BigUInt(99))
        XCTAssertNil(decodedPlain.currencyId)

        let equilibriumTransfer = TransferCall(
            dest: .rawString(Data([3, 4])),
            value: BigUInt(20),
            currencyId: .equilibrium(id: "EQ")
        )
        let equilibriumObject = try jsonDictionary(from: equilibriumTransfer)
        XCTAssertEqual(equilibriumObject["asset"] as? String, "EQ")
        XCTAssertEqual(equilibriumObject["to"] as? String, "0x0304")
        XCTAssertEqual(equilibriumObject["value"] as? String, "20")

        let soraAssetId = "0x" + String(repeating: "11", count: 32)
        let soraTransfer = TransferCall(
            dest: .accoundId(Data([5, 6])),
            value: BigUInt(30),
            currencyId: .soraAsset(id: soraAssetId)
        )
        let soraObject = try jsonDictionary(from: soraTransfer)
        XCTAssertNotNil(soraObject["asset_id"])
        XCTAssertEqual(soraObject["amount"] as? String, "30")
        XCTAssertEqual(soraObject["to"] as? String, Data([5, 6]).base64EncodedString())

        let assetsTransfer = TransferCall(
            dest: .rawString(Data([7, 8])),
            value: BigUInt(40),
            currencyId: .assets(id: "7")
        )
        let assetsObject = try jsonDictionary(from: assetsTransfer)
        XCTAssertEqual(assetsObject["id"] as? String, "7")
        XCTAssertEqual(assetsObject["target"] as? String, "0x0708")
        XCTAssertEqual(assetsObject["amount"] as? String, "40")

        let assetIdTransfer = TransferCall(
            dest: .rawString(Data([9, 10])),
            value: BigUInt(50),
            currencyId: .assetId(id: "42")
        )
        let assetIdObject = try jsonDictionary(from: assetIdTransfer)
        XCTAssertEqual(assetIdObject["dest"] as? String, "0x090a")
        XCTAssertEqual(assetIdObject["currency_id"] as? String, "42")
        XCTAssertEqual(assetIdObject["amount"] as? String, "50")

        let xcmTransfer = TransferCall(
            dest: .rawString(Data([11, 12])),
            value: BigUInt(60),
            currencyId: .xcm(id: "DOT")
        )
        let xcmObject = try jsonDictionary(from: xcmTransfer)
        XCTAssertEqual(xcmObject["dest"] as? String, "0x0b0c")
        XCTAssertEqual((xcmObject["currency_id"] as? [Any])?.first as? String, "XCM")
        XCTAssertEqual(xcmObject["amount"] as? String, "60")
    }

    func testIdentityResponse_whenDecodedFromWrappedAndDirectPayloads_thenReadsChainData() throws {
        let display = Data("Alice".utf8).base64EncodedString()
        let field = Data("matrix".utf8).base64EncodedString()
        let value = Data("@alice".utf8).base64EncodedString()
        let wrappedJson = """
        [
          {
            "info": {
              "display": ["raw", "\(display)"],
              "additional": [
                [
                  ["raw", "\(field)"],
                  ["raw", "\(value)"]
                ]
              ]
            }
          }
        ]
        """

        let wrapped = try decode(IdentityResponse.self, from: wrappedJson)

        XCTAssertEqual(wrapped.identity.info.display?.stringValue, "Alice")
        XCTAssertEqual(wrapped.identity.info.additional?.first?.field.stringValue, "matrix")
        XCTAssertEqual(wrapped.identity.info.additional?.first?.value.stringValue, "@alice")

        let directJson = """
        {
          "info": {
            "legal": ["raw", "\(Data("Soramitsu".utf8).base64EncodedString())"],
            "web": ["None"],
            "riot": ["None"],
            "email": ["None"],
            "image": ["None"],
            "twitter": ["None"]
          }
        }
        """
        let direct = try decode(IdentityResponse.self, from: directJson)

        XCTAssertEqual(direct.identity.info.legal?.stringValue, "Soramitsu")
        XCTAssertNil(direct.identity.info.web?.stringValue)
        XCTAssertNil(direct.identity.info.additional)
    }

    func testSuperIdentity_whenDecodedFromDataAndHexParents_thenReadsNameAndAccountId() throws {
        let parent = Data([1, 2, 3, 4])
        let childName = Data("child".utf8).base64EncodedString()
        let dataParentJson = #"["\#(parent.base64EncodedString())",["raw","\#(childName)"]]"#

        let dataParent = try decode(SuperIdentity.self, from: dataParentJson)

        XCTAssertEqual(dataParent.parentAccountId, parent)
        XCTAssertEqual(dataParent.name, "child")

        let hash = Data(repeating: 0xAB, count: H256.length).base64EncodedString()
        let hexParent = try decode(SuperIdentity.self, from: #"["0x01020304",["BlakeTwo256","\#(hash)"]]"#)

        XCTAssertEqual(hexParent.parentAccountId, parent)
        XCTAssertNil(hexParent.name)

        let encoded = try jsonArray(from: dataParent)
        XCTAssertEqual(encoded[0] as? String, parent.base64EncodedString())
        XCTAssertEqual((encoded[1] as? [Any])?.first as? String, "raw")
    }

    func testAccountIdentity_whenInitializedWithIdentityInfo_thenMapsDisplayFields() {
        let image = Data([1, 2, 3])
        let identityInfo = IdentityInfo(
            additional: nil,
            display: .raw(data: Data("Display".utf8)),
            legal: .raw(data: Data("Legal".utf8)),
            web: .raw(data: Data("https://soramitsu.co.jp".utf8)),
            riot: .raw(data: Data("@riot".utf8)),
            email: .raw(data: Data("alice@soramitsu.co.jp".utf8)),
            image: .raw(data: image),
            twitter: .raw(data: Data("@alice".utf8))
        )

        let child = AccountIdentity(
            name: "child",
            parentAddress: "parent-address",
            parentName: "parent",
            identity: identityInfo
        )

        XCTAssertEqual(child.displayName, "parent / child")
        XCTAssertEqual(child.parentAddress, "parent-address")
        XCTAssertEqual(child.legal, "Legal")
        XCTAssertEqual(child.web, "https://soramitsu.co.jp")
        XCTAssertEqual(child.riot, "@riot")
        XCTAssertEqual(child.email, "alice@soramitsu.co.jp")
        XCTAssertEqual(child.image, image)
        XCTAssertEqual(child.twitter, "@alice")

        let root = AccountIdentity(name: "root")
        XCTAssertEqual(root.displayName, "root")
        XCTAssertNil(root.parentName)
    }

    private func eventRecordJson(phase: String) -> String {
        """
        {
          "phase": ["\(phase)"],
          "event": [
            "system",
            [
              "ExtrinsicSuccess",
              {}
            ]
          ]
        }
        """
    }

    private func assetAccountInfoJson(status: String) -> String {
        #"{"balance":"42","status":["\#(status)"]}"#
    }

    private func decode<T: Decodable>(_ type: T.Type, from json: String) throws -> T {
        let data = try XCTUnwrap(json.data(using: .utf8))
        return try JSONDecoder().decode(type, from: data)
    }

    private func jsonArray<T: Encodable>(from value: T) throws -> [Any] {
        let data = try JSONEncoder().encode(value)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [Any])
    }

    private func jsonDictionary<T: Encodable>(from value: T) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}
