import UIKit
import CoreData
import Security
import IrohaCrypto
import SSFModels

@main final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, configurationForConnecting session: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: "Writer", sessionRole: session.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
}
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        window = UIWindow(windowScene: scene as! UIWindowScene)
        window!.rootViewController = UIViewController()
        window!.makeKeyAndVisible()
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        // Only fresh owned simulators; refusal makes a rerun unable to replace evidence.
        guard !FileManager.default.fileExists(atPath: documents.appendingPathComponent("historical-state.json").path) else { return }
        do {
            try writeHistoricalState(documents: documents)
        } catch {
            try! String(describing: error).write(to: documents.appendingPathComponent("writer-error.txt"), atomically: true, encoding: .utf8)
        }
    }
}
func writeHistoricalState(documents: URL) throws {
    let inputs = try JSONSerialization.jsonObject(with: Data(contentsOf: Bundle.main.url(forResource: "inputs", withExtension: "json")!)) as! [String: Any]
    let fixtures = inputs["wallets"] as! [[String: Any]]
    let keychain = Keychain()
    let factory = HistoricalAccountFactory(keystore: keychain)
    let model = NSManagedObjectModel(contentsOf: Bundle.main.url(forResource: "Historical", withExtension: "mom")!)!
    let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
    let folder = documents.appendingPathComponent("CoreData")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let store = try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil,
        at: folder.appendingPathComponent("UserDataModel.sqlite"), options: [NSSQLitePragmasOption: ["journal_mode": "DELETE"]])
    let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
    context.persistentStoreCoordinator = coordinator
    let mapper = ManagedMetaAccountMapper()
    var observations: [[String: Any]] = []
    var tags = [KeystoreTagV2.pincode.rawValue]
    for (index, fixture) in fixtures.enumerated() {
        let secret = fixture["secret"] as! [String: Any]
        let mnemonicText = secret["mnemonic"] as? String
        let substratePath = fixture["substrateDerivationPath"] as? String ?? ""
        let ethereumPath = fixture["ethereumDerivationPath"] as? String
        let crypto = CryptoType(rawValue: fixture["cryptoType"] as? String ?? "sr25519")!
        let operation: BaseOperation<MetaAccountModel>
        if fixture["importKind"] as? String == "ton" {
            let text = secret["tonPhrase"] as? String ?? secret["storedText"] as! String
            operation = factory.newTonMetaAccountOperation(request: MetaAccountImportTonMnemonicRequest(
                mnemonic: text, username: "Historical " + (fixture["id"] as! String)), isBackedUp: false)
        } else if fixture["importKind"] as? String == "json" {
            let request = MetaAccountImportKeystoreRequest(substrateKeystore: secret["keystoreJson"] as! String,
                ethereumKeystore: nil, substratePassword: secret["password"] as! String,
                ethereumPassword: nil, username: "Historical " + (fixture["id"] as! String), cryptoType: crypto)
            operation = factory.newMetaAccountOperation(request: request, isBackedUp: false)
        } else if fixture["importKind"] as? String == "seed" {
            let request = MetaAccountImportSeedRequest(substrateSeed: secret["seedHex"] as! String,
                ethereumSeed: secret["ethereumPrivateKeyHex"] as? String,
                username: "Historical " + (fixture["id"] as! String), substrateDerivationPath: substratePath,
                ethereumDerivationPath: ethereumPath, cryptoType: crypto)
            operation = factory.newMetaAccountOperation(request: request, isBackedUp: false)
        } else {
            let mnemonic = try IRMnemonicCreator().mnemonic(fromList: mnemonicText!)
            let request = MetaAccountImportMnemonicRequest(mnemonic: mnemonic, username: "Historical " + (fixture["id"] as! String),
                substrateDerivationPath: substratePath, ethereumDerivationPath: ethereumPath!, cryptoType: crypto, defaultChainId: nil)
            operation = factory.newMetaAccountOperation(request: request, isBackedUp: false)
        }
        operation.start()
        let wallet = try operation.result!.get()
        let managed = ManagedMetaAccountModel(info: wallet, isSelected: index == fixtures.count - 1)
        let entity = CDMetaAccount(context: context)
        try mapper.populate(entity: entity, from: managed, using: context)
        // Each historical save commits before next insertion, as in the app repository.
        try context.save()
        let roundtrip = try mapper.transform(entity: entity)
        precondition(roundtrip.info == wallet)
        if wallet.ecosystem.isTon {
            tags += [KeystoreTagV2.tonSecretKeyTagForMetaId(wallet.metaId), KeystoreTagV2.entropyTagForMetaId(wallet.metaId)]
            observations.append(["fixture": fixture["id"]!, "metaId": wallet.metaId, "name": wallet.name,
                "order": roundtrip.order, "isSelected": roundtrip.isSelected,
                "tonPublicKey": wallet.ecosystem.tonPublicKey!.toHex(),
                "tonAddress": wallet.ecosystem.tonAddress!.toString(bounceable: false),
                "tonSerializedAddress": entity.tonAddress!.toHex(),
                "tonContractVersion": wallet.ecosystem.tonContractVersion!.rawValue,
                "tonPhrase": secret["tonPhrase"] as? String ?? secret["storedText"] as! String])
            continue
        }
        tags.append(KeystoreTagV2.substrateSecretKeyTagForMetaId(wallet.metaId))
        if fixture["importKind"] as? String != "json" { tags.append(KeystoreTagV2.substrateSeedTagForMetaId(wallet.metaId)) }
        if mnemonicText != nil { tags.append(KeystoreTagV2.entropyTagForMetaId(wallet.metaId)) }
        if wallet.ecosystem.ethereumPublicKey != nil {
            tags += [KeystoreTagV2.ethereumSecretKeyTagForMetaId(wallet.metaId), KeystoreTagV2.ethereumSeedTagForMetaId(wallet.metaId)]
            if let path = ethereumPath, !path.isEmpty { tags.append(KeystoreTagV2.ethereumDerivationTagForMetaId(wallet.metaId)) }
        }
        if !substratePath.isEmpty { tags.append(KeystoreTagV2.substrateDerivationTagForMetaId(wallet.metaId)) }
        var addresses: [String: String] = [:]
        for prefix in [UInt16(0), 2, 42] {
            addresses[String(prefix)] = try SS58AddressFactory().address(fromAccountId: wallet.ecosystem.substrateAccountId!, type: prefix)
        }
        var observation: [String: Any] = ["fixture": fixture["id"]!, "metaId": wallet.metaId, "name": wallet.name,
            "order": roundtrip.order, "isSelected": roundtrip.isSelected,
            "cryptoType": crypto.rawValue, "substrateDerivationPath": substratePath, "substrateAddresses": addresses,
            "substratePublicKey": wallet.ecosystem.substratePublicKey!.toHex(),
            "substrateAccountId": wallet.ecosystem.substrateAccountId!.toHex()]
        if let value = wallet.ecosystem.ethereumPublicKey { observation["ethereumPublicKey"] = value.toHex() }
        if let value = wallet.ecosystem.ethereumAddress { observation["ethereumAddress"] = value.toHex() }
        if let value = ethereumPath { observation["ethereumDerivationPath"] = value }
        if let value = mnemonicText { observation["mnemonic"] = value }
        if let imports = fixture["chainImports"] as? [[String: Any]] {
            let rootTags = ["substrate": KeystoreTagV2.substrateSeedTagForMetaId(wallet.metaId),
                "ethereum": KeystoreTagV2.ethereumSeedTagForMetaId(wallet.metaId)]
            // Capture old stored root bytes before the exact old child imports overwrite these tags.
            observation["originalRootSeeds"] = try rootTags.mapValues { try keychain.fetchKey(for: $0).toHex() }
            observation["rootSeedTags"] = rootTags
            observation["chainAccounts"] = try importHistoricalChildren(imports, wallet: wallet, factory: factory,
                keychain: keychain, mapper: mapper, entity: entity, context: context, tags: &tags)
        }
        observations.append(observation)
    }
    var negativeImports: [[String: Any]] = []
    if inputs["profile"] as? String == "json-only-v1" {
        let secret = fixtures[0]["secret"] as! [String: Any]
        let password = secret["password"] as! String
        let v3 = (inputs["negative"] as! [String: Any])["ethereumV3"] as! String
        for (name, attemptPassword, ethereumJson) in [("wrong-password", password + "-wrong", nil as String?),
                ("NFD-password", password.decomposedStringWithCanonicalMapping, nil), ("ethereum-v3", password, v3)] {
            let before = try historicalSecrets()
            let request = MetaAccountImportKeystoreRequest(substrateKeystore: secret["keystoreJson"] as! String,
                ethereumKeystore: ethereumJson, substratePassword: attemptPassword,
                ethereumPassword: password, username: "Rejected fixture", cryptoType: .sr25519)
            let operation = factory.newMetaAccountOperation(request: request, isBackedUp: false)
            operation.start()
            guard case let .failure(error) = operation.result! else { fatalError("Historical negative import accepted") }
            let after = try historicalSecrets()
            precondition(after == before, "Rejected historical import mutated Keychain")
            negativeImports.append(["probe": name, "rejected": true, "keysUnchanged": true, "error": String(describing: error)])
        }
    }
    var emptyTagFixture: [String: Any] = [:]
    if inputs["profile"] as? String == "ton-typed-v1" {
        // Compatibility control through the exact old helper. Normal TON import above does not call saveSeed.
        let seed = try Data(hexStringSSF: (inputs["negative"] as! [String: Any])["emptyTagSeedHex"] as! String)
        precondition(KeystoreTagV2.seedKeyTag(for: .ton, metaId: "public-probe", accountId: nil) == "")
        try factory.saveSeed(seed, metaId: "public-probe", ecosystem: .ton)
        tags.append("")
        emptyTagFixture = ["origin": "explicit-old-helper-compatibility-probe", "publicCatalog": "GW-S1",
            "normalTonImportWritesEmptyTag": false, "bytes": seed.count]
    }
    try coordinator.remove(store)
    SettingsManager.shared.biometryEnabled = true
    let publicPin = inputs["publicPin"] as! String
    // Same dependency, identifier and UTF8 representation as the old PIN writer.
    KeychainManager.shared.saveSecret(publicPin, for: KeystoreTagV2.pincode.rawValue, completionQueue: .main) { success in
        do {
            precondition(success, "Historical PIN acknowledgement failed")
            var entries: [[String: Any]] = []
            for tag in tags {
                let bytes = try keychain.fetchKey(for: tag)
                let query: [String: Any] = [kSecClass as String: kSecClassKey, kSecAttrApplicationTag as String: Data(tag.utf8), kSecReturnAttributes as String: true]
                var result: CFTypeRef?
                let status = SecItemCopyMatching(query as CFDictionary, &result)
                precondition(status == errSecSuccess)
                let attributes = result as! [String: Any]
                precondition(attributes[kSecAttrAccessible as String] as? String == kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String)
                entries.append(["tag": tag, "hex": bytes.toHex(), "accessible": attributes[kSecAttrAccessible as String]!, "accessGroup": attributes[kSecAttrAccessGroup as String] ?? ""])
            }
            let result: [String: Any] = ["profile": inputs["profile"] ?? "mnemonic-roots-v1", "release": "4.0.4", "appRevision": "195b0230743fa3c5fb74fbf05f4e4ee38b2d0bcf", "wallets": observations, "keychain": entries, "negativeImports": negativeImports, "emptyTagFixture": emptyTagFixture, "publicPin": publicPin, "biometryEnabled": SettingsManager.shared.biometryEnabled!, "bundleId": Bundle.main.bundleIdentifier!]
            let data = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: documents.appendingPathComponent("historical-state.json"), options: .atomic)
        } catch {
            try! String(describing: error).write(to: documents.appendingPathComponent("writer-error.txt"), atomically: true, encoding: .utf8)
        }
    }
}

// Whole application-accessible SecItem key inventory, not only the expected fixture tags.
func historicalSecrets() throws -> [String: String] {
    let query: [String: Any] = [kSecClass as String: kSecClassKey, kSecReturnAttributes as String: true,
        kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitAll]
    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    if status == errSecItemNotFound { return [:] }
    guard status == errSecSuccess else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(status)) }
    var inventory: [String: String] = [:]
    for record in result as! [[String: Any]] {
        let tag = (record[kSecAttrApplicationTag as String] as! Data).base64EncodedString()
        precondition(inventory[tag] == nil)
        inventory[tag] = (record[kSecValueData as String] as! Data).base64EncodedString()
    }
    return inventory
}

// Input descriptors contain only fields read by the unchanged historical import bodies.
func importHistoricalChildren(_ imports: [[String: Any]], wallet: MetaAccountModel,
    factory: HistoricalAccountFactory, keychain: Keychain, mapper: ManagedMetaAccountMapper,
    entity: CDMetaAccount, context: NSManagedObjectContext, tags: inout [String]) throws -> [[String: Any]] {
    var updated = wallet
    var observations: [[String: Any]] = []
    for input in imports {
        let secret = input["secret"] as! [String: Any]
        let kind = input["importKind"] as! String
        let ethereum = input["ethereumBased"] as! Bool
        let path = input["derivationPath"] as! String
        let curve = CryptoType(rawValue: input["cryptoType"] as! String)!
        let chain = ChainModel(chainId: input["chainId"] as! String, ecosystem: ethereum ? .ethereumBased : .substrate)
        let operation: BaseOperation<MetaAccountModel>
        if kind == "mnemonic" {
            operation = factory.importChainAccountOperation(request: ChainAccountImportMnemonicRequest(
                wallet: updated, mnemonic: try IRMnemonicCreator().mnemonic(fromList: secret["mnemonic"] as! String),
                username: input["id"] as! String, derivationPath: path, cryptoType: curve, chains: [chain]))
        } else if kind == "seed" {
            operation = factory.importChainAccountOperation(request: ChainAccountImportSeedRequest(
                wallet: updated, seed: secret["seedHex"] as! String, username: input["id"] as! String,
                derivationPath: path, cryptoType: curve, chains: [chain]))
        } else {
            operation = factory.importChainAccountOperation(request: ChainAccountImportKeystoreRequest(
                wallet: updated, keystore: secret["keystoreJson"] as! String, password: secret["password"] as! String,
                username: input["id"] as! String, cryptoType: curve, chains: [chain]))
        }
        operation.start()
        updated = try operation.result!.get()
        // Match old SelectedWalletSettings.performSave: retain the existing managed row's order.
        let previous = try mapper.transform(entity: entity)
        try mapper.populate(entity: entity, from: ManagedMetaAccountModel(
            info: updated, isSelected: true, order: previous.order), using: context)
        try context.save()
        let roundtrip = try mapper.transform(entity: entity)
        precondition(roundtrip.info == updated)
        let child = updated.chainAccounts.first { $0.chainId == chain.chainId }!
        let secretTag = KeystoreTagV2.secretKeyTag(for: chain.ecosystem, metaId: wallet.metaId, accountId: child.accountId)
        tags.append(secretTag)
        if kind == "mnemonic" { tags.append(KeystoreTagV2.entropyTagForMetaId(wallet.metaId, accountId: child.accountId)) }
        if !path.isEmpty {
            tags.append(ethereum ? KeystoreTagV2.ethereumDerivationTagForMetaId(wallet.metaId, accountId: child.accountId)
                : KeystoreTagV2.substrateDerivationTagForMetaId(wallet.metaId, accountId: child.accountId))
        }
        // Capture at the moment the historical writer produced it, never from an RC recipe.
        let exportTag = kind == "json" || ethereum ? secretTag
            : KeystoreTagV2.seedKeyTag(for: chain.ecosystem, metaId: wallet.metaId, accountId: nil)
        let exportSeed = try keychain.fetchKey(for: exportTag)
        let address = ethereum ? "0x" + child.accountId.toHex()
            : try SS58AddressFactory().address(fromAccountId: child.accountId, type: UInt16(input["addressPrefix"] as! Int))
        var observation: [String: Any] = ["fixture": input["id"]!, "importKind": kind, "chainId": chain.chainId,
            "cryptoType": child.cryptoType, "publicKey": child.publicKey.toHex(), "accountId": child.accountId.toHex(),
            "ethereumBased": ethereum, "addressPrefix": input["addressPrefix"]!, "address": address,
            "derivationPath": path, "expectedExportSeed": exportSeed.toHex(), "exportCaptureTag": exportTag]
        if let phrase = secret["mnemonic"] { observation["mnemonic"] = phrase }
        observations.append(observation)
    }
    precondition(updated.chainAccounts.count == imports.count)
    return observations
}
