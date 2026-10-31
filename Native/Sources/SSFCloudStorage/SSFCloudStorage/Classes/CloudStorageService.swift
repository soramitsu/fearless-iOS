import Foundation
import GoogleAPIClientForREST_Drive
import GoogleAPIClientForRESTCore
import GoogleSignIn
import IrohaCrypto
import SSFModels
import SSFUtils
import TweetNacl

public enum KeystoreConstants {
    public static let nonceLength = 24
    public static let encryptionKeyLength = 32
}

public enum CloudStorageAccountState {
    case authorized
    case notAuthorized
}

public protocol CloudStorageServiceProtocol: AnyObject {
    var isUserAuthorized: Bool { get }
    func signInIfNeeded() async throws -> CloudStorageAccountState
    func getBackupAccounts() async throws -> [OpenBackupAccount]
    func saveBackup(account: OpenBackupAccount, password: String) async throws
    /// Read and decrypt the exact Drive file created by this upload.
    func saveBackupAndImport(account: OpenBackupAccount, password: String) async throws
        -> OpenBackupAccount
    func importBackup(account: OpenBackupAccount, password: String) async throws
        -> OpenBackupAccount
    func deleteBackup(account: OpenBackupAccount) async throws
    func disconnect()
}

protocol GoogleDriveServiceProtocol: AnyObject {
    var googleDriveService: GoogleService { get }
}

public class CloudStorageService: NSObject, GoogleDriveServiceProtocol {
    public var isUserAuthorized: Bool { singInProvider.currentUser != nil }
    public var googleDriveService: GoogleService

    private weak var uiDelegate: UIViewController?
    private let singInProvider: GIDSignIn
    private let queue: DispatchQueueType
    private let encryptionService: EncryptionServiceProtocol
    private let fileFactory: BackupFileFactoryProtocol

    public init(
        uiDelegate: UIViewController,
        signInProvider: GIDSignIn = GIDSignIn.sharedInstance,
        googleDriveService: GoogleService =
            BaseGoogleService(googleService: GTLRDriveService()),
        queue: DispatchQueueType = DispatchQueue.main,
        encryptionService: EncryptionServiceProtocol = EncryptionService(),
        fileFactory: BackupFileFactoryProtocol? = nil
    ) {
        self.uiDelegate = uiDelegate
        singInProvider = signInProvider
        self.googleDriveService = googleDriveService
        self.queue = queue
        self.encryptionService = encryptionService
        self.fileFactory = fileFactory ?? BackupFileFactory(service: encryptionService)
    }

    private func getAppFolderFiles(
        from q: String? = nil,
        withField: Bool = false,
        orderBy: String? = nil
    ) async throws -> [GTLRDrive_File] {
        var files: [GTLRDrive_File] = []
        var pageToken: String?
        var seenTokens = Set<String>()
        // A truncated list must not silently hide a newer backup generation.
        for _ in 0 ..< 20 {
            let query = GTLRDriveQuery_FilesList.query()
            query.spaces = "appDataFolder"
            query.fields = withField ? "nextPageToken,incompleteSearch,files(id,name,description,createdTime)" :
                "nextPageToken,incompleteSearch,files(id,name,description)"
            query.q = q
            query.orderBy = orderBy
            query.pageSize = 1000
            query.pageToken = pageToken

            let result = try await googleDriveService.executeQuery(query)
            guard let list = result.file as? GTLRDrive_FileList else {
                throw CloudStorageServiceError.notFound
            }
            guard list.incompleteSearch?.boolValue != true else {
                throw CloudStorageServiceError.notFound
            }
            files.append(contentsOf: list.files ?? [])
            guard let next = list.nextPageToken, !next.isEmpty else { return files }
            guard seenTokens.insert(next).inserted else {
                throw CloudStorageServiceError.notFound
            }
            pageToken = next
        }
        throw CloudStorageServiceError.notFound
    }

    private func getBackupFolderIds(createIfMissing: Bool = false) async throws -> [String] {
        let q = "name = 'backupFolder' and mimeType = 'application/vnd.google-apps.folder' " +
            "and 'appDataFolder' in parents and trashed = false"
        let files = try await getAppFolderFiles(from: q)
        if files.isEmpty, createIfMissing {
            return [try await createBackupFolder()]
        }
        let ids = try files.map { file -> String in
            guard let id = file.identifier, !id.isEmpty else {
                throw CloudStorageServiceError.notFound
            }
            return id
        }
        return Array(Set(ids)).sorted()
    }

    private func getParentFolder() async throws -> String {
        guard let folderId = try await getBackupFolderIds(createIfMissing: true).first else {
            throw CloudStorageServiceError.notFound
        }
        return folderId
    }

    private func getMobileBackupFiles(in folderIds: [String]) async throws -> [GTLRDrive_File] {
        var files: [GTLRDrive_File] = []
        for folderId in folderIds {
            let q = "'\(folderId)' in parents and trashed = false " +
                "and mimeType != 'application/vnd.google-apps.folder'"
            files.append(contentsOf: try await getAppFolderFiles(
                from: q,
                withField: true,
                orderBy: "createdTime desc"
            ))
        }
        return files
    }

    private func orderedBackupFileIds(
        named name: String,
        in files: [GTLRDrive_File]
    ) throws -> [String] {
        var seenIds = Set<String>()
        var candidates: [(id: String, createdAt: Date?)] = []
        for file in files where file.name == name {
            guard let id = file.identifier, !id.isEmpty else {
                throw CloudStorageServiceError.incorectJson
            }
            if seenIds.insert(id).inserted {
                candidates.append((id, file.createdTime?.date))
            }
        }
        // A single historical backup does not need a timestamp. Across folders,
        // list order is not a safe substitute for creation time.
        guard candidates.count > 1 else { return candidates.map(\.id) }
        let dated = try candidates.map { candidate -> (id: String, createdAt: Date) in
            guard let createdAt = candidate.createdAt else {
                throw CloudStorageServiceError.incorectJson
            }
            return (candidate.id, createdAt)
        }.sorted { $0.createdAt > $1.createdAt }
        for index in 1 ..< dated.count where dated[index - 1].createdAt == dated[index].createdAt {
            throw CloudStorageServiceError.incorectJson
        }
        return dated.map(\.id)
    }

    private func createBackupFolder() async throws -> String {
        let file = GTLRDrive_File()
        file.name = "backupFolder"
        file.parents = ["appDataFolder"]
        file.mimeType = "application/vnd.google-apps.folder"

        let query = GTLRDriveQuery_FilesCreate.query(withObject: file, uploadParameters: nil)
        query.fields = "id"

        let results = try await googleDriveService.executeQuery(query)
        guard let fileId = (results.file as? GTLRDrive_File)?.identifier,
              !fileId.isEmpty else {
            throw CloudStorageServiceError.notFound
        }
        return fileId
    }

    private func executeQueryForMedia(withFileId: String) async throws -> Data {
        let query = GTLRDriveQuery_FilesGet.queryForMedia(withFileId: withFileId)
        let results = try await googleDriveService.executeQuery(query)

        guard let data = (results.file as? GTLRDataObject)?.data else {
            throw CloudStorageServiceError.notFound
        }

        return data
    }
}

// MARK: - CloudStorageServiceProtocol

extension CloudStorageService: CloudStorageServiceProtocol {
    public func signInIfNeeded() async throws -> CloudStorageAccountState {
        guard let uiDelegate = uiDelegate else {
            return .notAuthorized
        }

        if let user = singInProvider.currentUser {
            googleDriveService.set(authorizer: user.fetcherAuthorizer)
            return .authorized
        }

        let result = try await signIn(uiDelegate: uiDelegate)
        googleDriveService.set(authorizer: result?.user.fetcherAuthorizer)
        return .authorized
    }

    public func getBackupAccounts() async throws -> [OpenBackupAccount] {
        let mobileAccounts = try await getBackupAccountsForMobileExtension()
        let extensionAccounts = try await getBackupAccountsForFearlessExtension()

        let filteredExtensionAccounts = extensionAccounts.filter { extensionAccount in
            !mobileAccounts.contains(where: { $0.address == extensionAccount.address })
        }
        let accounts = mobileAccounts + filteredExtensionAccounts
        return accounts
    }

    private func uploadBackup(account: OpenBackupAccount, password: String) async throws
        -> (fileId: String, bytes: Data)
    {
        let fileUrl = try fileFactory.createFile(from: account, password: password)
        // The file holds the encrypted phrase and seeds; keep only its bytes for the upload.
        let contents = Result { try Data(contentsOf: fileUrl) }
        try? FileManager.default.removeItem(at: fileUrl)
        let data = try contents.get()

        let signInState = try await signInIfNeeded()

        guard signInState == .authorized else {
            throw CloudStorageServiceError.notAuthorized
        }

        let folderId = try await getParentFolder()

        let file = GTLRDrive_File()
        file.name = "\(account.address).json"
        file.descriptionProperty = account.name
        file.parents = ["\(folderId)"]

        let params = GTLRUploadParameters(data: data, mimeType: "application/json")
        params.shouldUploadWithSingleRequest = true

        let query = GTLRDriveQuery_FilesCreate.query(withObject: file, uploadParameters: params)
        query.fields = "id"

        let result = try await googleDriveService.executeQuery(query)
        guard let fileId = (result.file as? GTLRDrive_File)?.identifier,
              !fileId.isEmpty else {
            throw CloudStorageServiceError.notFound
        }
        return (fileId, data)
    }

    public func saveBackup(account: OpenBackupAccount, password: String) async throws {
        _ = try await uploadBackup(account: account, password: password)
    }

    public func saveBackupAndImport(
        account: OpenBackupAccount,
        password: String
    ) async throws -> OpenBackupAccount {
        let uploaded = try await uploadBackup(account: account, password: password)
        let downloaded = try await executeQueryForMedia(withFileId: uploaded.fileId)
        guard downloaded == uploaded.bytes else {
            throw CloudStorageServiceError.readbackMismatch
        }
        return try decodeMobileBackup(downloaded, password: password)
    }

    public func importBackup(
        account: OpenBackupAccount,
        password: String
    ) async throws -> OpenBackupAccount {
        do {
            let mobileAccount = try await fetchBackup(account: account, password: password)
            return mobileAccount
        } catch {
            if let error = error as? CloudStorageServiceError {
                switch error {
                case .notFound:
                    let extensionAccount = try await executeExtension(
                        account: account,
                        password: password
                    )
                    return extensionAccount
                case .incorectPassword, .incorectJson, .notAuthorized, .readbackMismatch:
                    throw error
                }
            }
            throw error
        }
    }

    public func deleteBackup(account: OpenBackupAccount) async throws {
        let mobileAccounts = try await getBackupAccountsForMobileExtension()

        if mobileAccounts.contains(where: { $0.address == account.address }) {
            try await delete(backupAccount: account)
            return
        }
        let extensionAccounts = try await getBackupAccountsForFearlessExtension()
        if extensionAccounts.contains(where: { $0.address == account.address }) {
            throw FearlessExtensionError.cantRemoveExtensionBackup
        }

        throw FearlessExtensionError.backupNotFound
    }

    public func disconnect() {
        singInProvider.signOut()
        singInProvider.disconnect()
    }
}

extension CloudStorageService {
    private func signIn(uiDelegate: UIViewController) async throws -> GIDSignInResult? {
        try await withCheckedThrowingContinuation { [weak self] continuation in
            self?.queue.async { [weak self] in
                self?.singInProvider.signIn(
                    withPresenting: uiDelegate,
                    hint: nil,
                    additionalScopes: [kGTLRAuthScopeDriveAppdata],
                    completion: { result, error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(returning: result)
                        }
                    }
                )
            }
        }
    }

    private func getBackupAccountsForMobileExtension() async throws -> [OpenBackupAccount] {
        let signInState = try await signInIfNeeded()

        guard signInState == .authorized else {
            throw CloudStorageServiceError.notAuthorized
        }

        let folderIds = try await getBackupFolderIds()
        let files = try await getMobileBackupFiles(in: folderIds)
        var seenAddresses = Set<String>()
        let accounts = files.compactMap { file -> OpenBackupAccount? in
            guard let name = file.name, name.hasSuffix(".json") else { return nil }
            let address = String(name.dropLast(".json".count))
            guard !address.isEmpty, seenAddresses.insert(address).inserted else { return nil }
            return OpenBackupAccount(name: file.descriptionProperty, address: address)
        }

        return accounts
    }

    private func getBackupAccountsForFearlessExtension() async throws -> [OpenBackupAccount] {
        let signInState = try await signInIfNeeded()

        guard signInState == .authorized else {
            throw CloudStorageServiceError.notAuthorized
        }

        let q = "'appDataFolder' in parents and mimeType != 'application/vnd.google-apps.folder'"
        let files = try await getAppFolderFiles(from: q, withField: true)

        let accounts: [OpenBackupAccount] = files.compactMap {
            guard let descriptionProperty = $0.descriptionProperty,
                  descriptionProperty.contains("/") == true,
                  let addressSubSequence = $0.descriptionProperty?.split(separator: "/").first,
                  let ethereumJsonFileId = $0.descriptionProperty?.split(separator: "/").last else
            {
                return nil
            }

            return OpenBackupAccount(
                name: $0.name?.replacingOccurrences(of: ".json", with: ""),
                address: String(addressSubSequence),
                ethDerivationPath: String(ethereumJsonFileId)
            )
        }

        return accounts
    }

    private func fetchBackup(
        account: OpenBackupAccount,
        password: String
    ) async throws -> OpenBackupAccount {
        let signInState = try await signInIfNeeded()

        guard signInState == .authorized else {
            throw CloudStorageServiceError.notAuthorized
        }

        let folderIds = try await getBackupFolderIds()
        let files = try await getMobileBackupFiles(in: folderIds)
        let fileIds = try orderedBackupFileIds(named: "\(account.address).json", in: files)
        guard !fileIds.isEmpty else {
            throw CloudStorageServiceError.notFound
        }
        var decodeError: CloudStorageServiceError = .incorectJson
        for fileId in fileIds {
            // A transport or authentication failure is not evidence that an
            // older backup is current. Only structurally malformed bytes allow fallback.
            let data = try await executeQueryForMedia(withFileId: fileId)
            do {
                let decoded = try decodeMobileBackup(data, password: password)
                guard decoded.address == account.address else {
                    throw CloudStorageServiceError.readbackMismatch
                }
                return decoded
            } catch let error as CloudStorageServiceError {
                switch error {
                case .incorectJson:
                    decodeError = error
                case .incorectPassword, .notFound, .notAuthorized, .readbackMismatch:
                    throw error
                }
            }
        }
        throw decodeError
    }

    private func decodeMobileBackup(_ data: Data, password: String) throws -> OpenBackupAccount {
        guard let account = try? JSONDecoder().decode(EcryptedBackupAccount.self, from: data) else {
            throw CloudStorageServiceError.incorectJson
        }

        let passphrase = try? encryptionService.getDecrypted(
            from: account.encryptedMnemonicPhrase,
            password: password
        )
        let substrateDerivationPath = try? encryptionService.getDecrypted(
            from: account.encryptedSubstrateDerivationPath,
            password: password
        )

        var ethDerivationPath: String?

        if let path = account.encryptedEthDerivationPath, !path.isEmpty {
            guard let ethPath = try? encryptionService.getDecrypted(from: path, password: password) else {
                throw CloudStorageServiceError.incorectPassword
            }
            ethDerivationPath = ethPath
        }

        let encryptedSeed = account.encryptedSeed
        let substrateSeed = try? encryptionService.getDecrypted(
            from: encryptedSeed?.substrateSeed,
            password: password
        )
        let ethereumSeed = try? encryptionService.getDecrypted(
            from: encryptedSeed?.ethSeed,
            password: password
        )
        if account.encryptedMnemonicPhrase != nil && passphrase == nil ||
            account.encryptedSubstrateDerivationPath != nil && substrateDerivationPath == nil ||
            encryptedSeed?.substrateSeed != nil && substrateSeed == nil ||
            encryptedSeed?.ethSeed != nil && ethereumSeed == nil {
            throw CloudStorageServiceError.incorectPassword
        }
        if account.backupAccountType?.contains("passphrase") == true && passphrase?.isEmpty != false ||
            account.backupAccountType?.contains("seed") == true &&
            substrateSeed?.isEmpty != false && ethereumSeed?.isEmpty != false ||
            account.backupAccountType?.contains("json") == true &&
            account.json?.substrateJson?.isEmpty != false && account.json?.ethJson?.isEmpty != false {
            throw CloudStorageServiceError.incorectJson
        }
        if passphrase?.isEmpty != false && substrateSeed?.isEmpty != false &&
            ethereumSeed?.isEmpty != false && account.json?.substrateJson?.isEmpty != false &&
            account.json?.ethJson?.isEmpty != false {
            throw CloudStorageServiceError.incorectJson
        }
        for json in [account.json?.substrateJson, account.json?.ethJson].compactMap({ $0 }) {
            guard let bytes = json.data(using: .utf8),
                  let definition = try? JSONDecoder().decode(KeystoreDefinition.self, from: bytes) else {
                throw CloudStorageServiceError.incorectJson
            }
            do {
                let restored = try KeystoreExtractor().extractFromDefinition(
                    definition, password: password
                )
                guard !restored.secretKeyData.isEmpty, !restored.publicKeyData.isEmpty else {
                    throw CloudStorageServiceError.incorectPassword
                }
            } catch let error as KeystoreExtractorError {
                switch error {
                case .invalidBase64, .invalidDataLength, .missingPkcs8Header, .missingPkcs8Divider:
                    // Explicit structural errors permit trying an older backup generation.
                    throw CloudStorageServiceError.incorectJson
                default:
                    throw CloudStorageServiceError.incorectPassword
                }
            } catch {
                // Authentication failures do not establish that a backup is malformed.
                throw CloudStorageServiceError.incorectPassword
            }
        }

        let decodedAccount = OpenBackupAccount(
            name: account.name,
            address: account.address,
            passphrase: passphrase,
            cryptoType: account.cryptoType,
            substrateDerivationPath: substrateDerivationPath,
            ethDerivationPath: ethDerivationPath,
            backupAccountType: account.backupAccountType?
                .compactMap {
                    OpenBackupAccount.BackupAccountType(rawValue: $0)
                },
            json: OpenBackupAccount.Json(
                substrateJson: account.json?.substrateJson,
                ethJson: account.json?.ethJson
            ),
            encryptedSeed: OpenBackupAccount.Seed(
                substrateSeed: substrateSeed,
                ethSeed: ethereumSeed
            )
        )

        return decodedAccount
    }

    private func executeExtension(
        account: OpenBackupAccount,
        password: String
    ) async throws -> OpenBackupAccount {
        let signInState = try await signInIfNeeded()

        guard signInState == .authorized else {
            throw CloudStorageServiceError.notAuthorized
        }

        let q = "'appDataFolder' in parents and mimeType != 'application/vnd.google-apps.folder'"
        let extensionAccounts = try await getAppFolderFiles(
            from: q,
            withField: true
        )

        guard let fileId = extensionAccounts.first(where: {
            $0.descriptionProperty?.contains(account.address) == true
        })?.identifier,
            let ethereumFileId = account.ethDerivationPath else
        {
            throw CloudStorageServiceError.notFound
        }

        let substrateData = try await executeQueryForMedia(withFileId: fileId)
        let ethereumData = try await executeQueryForMedia(withFileId: ethereumFileId)
        return try OpenBackupAccount.create(
            address: account.address,
            password: password,
            substrateData: substrateData,
            ethereumData: ethereumData
        )
    }

    private func delete(backupAccount: OpenBackupAccount) async throws {
        let signInState = try await signInIfNeeded()

        guard signInState == .authorized else {
            throw CloudStorageServiceError.notAuthorized
        }

        let folderIds = try await getBackupFolderIds()
        let files = try await getMobileBackupFiles(in: folderIds)
        let fileIds = try orderedBackupFileIds(named: "\(backupAccount.address).json", in: files)
        guard !fileIds.isEmpty else {
            throw CloudStorageServiceError.notFound
        }
        // If a deletion fails partway through, keep the latest generation available.
        for id in fileIds.reversed() {
            _ = try await googleDriveService.executeQuery(
                GTLRDriveQuery_FilesDelete.query(withFileId: id)
            )
        }
    }
}
