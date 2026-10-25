import GoogleAPIClientForREST_Drive
import GoogleAPIClientForRESTCore
import GoogleSignIn
import SSFUtils
import XCTest

@testable import SSFCloudStorage

final class CloudStorageServiceTests: XCTestCase {
    private enum CloudStorageServiceTestsError: Error {
        case noSignInProviderExists
    }

    var service: CloudStorageService?
    var signInProvider: GIDSignInMock?
    var delegate: UIViewController?
    var queue: DispatchQueueType?
    var factory: BackupFileFactoryMock?
    var encryptionService: EncryptionServiceMock?
    var googleService: GoogleServiceMock?

    override func setUpWithError() throws {
        try super.setUpWithError()

        let delegate = UIViewController()
        let signInProvider = GIDSignInMock.sharedInstance as? GIDSignInMock
        let queue = DispatchQueueMock()
        let googleService = GoogleServiceMock()
        let factory = BackupFileFactoryMock()
        let encryptionService = EncryptionServiceMock()

        guard let signInProvider else { throw CloudStorageServiceTestsError.noSignInProviderExists }

        self.signInProvider = signInProvider
        self.delegate = delegate
        self.queue = queue
        self.googleService = googleService
        self.encryptionService = encryptionService
        self.factory = factory

        service = CloudStorageService(
            uiDelegate: delegate,
            signInProvider: signInProvider,
            googleDriveService: googleService,
            queue: queue,
            encryptionService: encryptionService,
            fileFactory: factory
        )
    }

    override func tearDownWithError() throws {
        try super.tearDownWithError()
        service = nil
        signInProvider?._currentUser = nil
        signInProvider?.signInCallsCount = 0
        signInProvider?.signInClosure = nil
        signInProvider = nil
        delegate = nil
        queue = nil
        googleService = nil
        encryptionService = nil
        factory = nil
    }

    func testUserAuthorized() {
        // arrange
        signInProvider?._currentUser = TestData.user

        // assert
        XCTAssertTrue(service?.isUserAuthorized ?? false)
    }

    func testSignInIfNeeded() async throws {
        // arrange
        signInProvider?._currentUser = TestData.user

        // act
        let state = try await service?.signInIfNeeded()

        // assert
        XCTAssertEqual(state, .authorized)
        XCTAssertEqual(googleService?.setAuthorizerCallsCount, 1)
        XCTAssertTrue(googleService?.setAuthorizerCalled ?? false)
    }

    func testSignInIfNeededWithError() async throws {
        // arrange
        signInProvider?.signInClosure = { [weak self] _, _, _, completion in
            completion?(nil, CloudStorageServiceError.notAuthorized)
        }

        // act
        do {
            let state = try await service?.signInIfNeeded()
        } catch {
            // assert
            XCTAssertEqual(
                error.localizedDescription,
                CloudStorageServiceError.notAuthorized.localizedDescription
            )
            XCTAssertEqual(signInProvider?.signInCallsCount, 1)
            XCTAssertTrue(signInProvider?.signInCalled ?? false)
        }
    }

    func testGetBackupAccounts() async throws {
        // arrange
        signInProvider?._currentUser = TestData.user

        // act
        let accounts = try await service?.getBackupAccounts()

        // assert
        XCTAssertEqual(accounts?.count, 1)
        XCTAssertEqual(accounts?.first?.address, TestData.account.address)

        XCTAssertEqual(googleService?.executeQueryCallsCount, 3)
        XCTAssertTrue(googleService?.executeQueryCalled ?? false)
    }

    func testGetBackupAccountsAcrossDuplicateFoldersDeduplicatesAddress() async throws {
        signInProvider?._currentUser = TestData.user
        let accountName = "\(TestData.account.address).json"
        googleService?.executeQueryHandler = { query in
            guard let list = query as? GTLRDriveQuery_FilesList else { return nil }
            if list.q?.contains("name = 'backupFolder'") == true {
                return (GoogleServiceTicketMock(), self.driveList([
                    ("folder-a", "backupFolder"), ("folder-b", "backupFolder"),
                ]))
            }
            if list.q?.contains("'folder-a' in parents") == true {
                return (GoogleServiceTicketMock(), self.driveList([("old-file", accountName)]))
            }
            if list.q?.contains("'folder-b' in parents") == true {
                return (GoogleServiceTicketMock(), self.driveList([("new-file", accountName)]))
            }
            return (GoogleServiceTicketMock(), self.driveList([]))
        }

        let accounts = try await service?.getBackupAccounts()

        XCTAssertEqual(accounts?.count, 1)
        XCTAssertEqual(accounts?.first?.address, TestData.account.address)
    }

    func testSaveBackupAccount() async throws {
        // arrange
        signInProvider?._currentUser = TestData.user
        factory?.createFileReturnValue = try getURL()
        // act
        try await service?.saveBackup(account: TestData.account, password: "1")

        // assert
        XCTAssertEqual(googleService?.setAuthorizerCallsCount, 1)
        XCTAssertEqual(googleService?.executeQueryCallsCount, 2)
        XCTAssertEqual(factory?.createFileCallsCount, 1)

        XCTAssertTrue(googleService?.setAuthorizerCalled ?? false)
        XCTAssertTrue(googleService?.executeQueryCalled ?? false)
        XCTAssertTrue(factory?.createFileCalled ?? false)
    }

    func testSaveBackupAndImportReadsExactCreatedFileDespiteOlderDuplicate() async throws {
        signInProvider?._currentUser = TestData.user
        let fileURL = try getURL()
        factory?.createFileReturnValue = fileURL
        let uploaded = try Data(contentsOf: fileURL)
        googleService?.executeQueryHandler = { query in
            if query is GTLRDriveQuery_FilesCreate {
                let file = GTLRDrive_File()
                file.identifier = "new-file"
                return (GoogleServiceTicketMock(), file)
            }
            if let get = query as? GTLRDriveQuery_FilesGet {
                XCTAssertEqual(get.fileId, "new-file")
                let media = GTLRDataObject()
                media.data = uploaded
                return (GoogleServiceTicketMock(), media)
            }
            return nil
        }

        let account = try await service?.saveBackupAndImport(account: TestData.account, password: "1")

        XCTAssertEqual(account?.address, TestData.account.address)
        XCTAssertEqual(account?.name, TestData.account.name)
        XCTAssertEqual(googleService?.executeQueryCallsCount, 3)
    }

    func testSaveBackupAndImportRejectsDifferentCreatedFileReadback() async throws {
        signInProvider?._currentUser = TestData.user
        factory?.createFileReturnValue = try getURL()
        googleService?.executeQueryHandler = { query in
            if query is GTLRDriveQuery_FilesCreate {
                let file = GTLRDrive_File()
                file.identifier = "new-file"
                return (GoogleServiceTicketMock(), file)
            }
            if query is GTLRDriveQuery_FilesGet {
                let media = GTLRDataObject()
                media.data = Data("different backup".utf8)
                return (GoogleServiceTicketMock(), media)
            }
            return nil
        }

        do {
            _ = try await service?.saveBackupAndImport(account: TestData.account, password: "1")
            XCTFail("A different Drive object must not verify the upload")
        } catch CloudStorageServiceError.readbackMismatch {
            // The old backup is retained; the new backup is not marked complete.
        }
    }

    func testSaveBackupAndImportRequiresCreatedFileId() async throws {
        signInProvider?._currentUser = TestData.user
        factory?.createFileReturnValue = try getURL()
        googleService?.executeQueryHandler = { query in
            if query is GTLRDriveQuery_FilesCreate {
                return (GoogleServiceTicketMock(), GTLRDrive_File())
            }
            if query is GTLRDriveQuery_FilesGet {
                XCTFail("Readback must not use an unbound Drive file")
            }
            return nil
        }

        do {
            _ = try await service?.saveBackupAndImport(account: TestData.account, password: "1")
            XCTFail("Upload without an exact file ID must fail closed")
        } catch CloudStorageServiceError.notFound {
            // A missing Drive ID cannot establish which file was uploaded.
        }
    }

    func testImportSelectsNewestExactNameAcrossPages() async throws {
        signInProvider?._currentUser = TestData.user
        let encrypted = try JSONEncoder().encode(TestData.encryptedAccount)
        let expectedName = "\(TestData.account.address).json"
        googleService?.executeQueryHandler = { query in
            if let list = query as? GTLRDriveQuery_FilesList {
                if list.q?.contains("name = 'backupFolder'") == true {
                    return (GoogleServiceTicketMock(), self.driveList([("folder", "backupFolder")]))
                }
                XCTAssertEqual(list.orderBy, "createdTime desc")
                if list.pageToken == nil {
                    let page = self.driveList([
                        ("collision", "other-\(expectedName)"),
                        ("new-file", expectedName),
                    ], createdTimes: ["new-file": "2026-09-24T10:00:00Z"])
                    page.nextPageToken = "next-page"
                    return (GoogleServiceTicketMock(), page)
                }
                XCTAssertEqual(list.pageToken, "next-page")
                return (GoogleServiceTicketMock(), self.driveList(
                    [("old-file", expectedName)],
                    createdTimes: ["old-file": "2026-09-23T10:00:00Z"]
                ))
            }
            if let get = query as? GTLRDriveQuery_FilesGet {
                XCTAssertEqual(get.fileId, "new-file")
                let media = GTLRDataObject()
                media.data = encrypted
                return (GoogleServiceTicketMock(), media)
            }
            return nil
        }

        let account = try await service?.importBackup(account: TestData.account, password: "1")

        XCTAssertEqual(account?.address, TestData.account.address)
        XCTAssertEqual(googleService?.executeQueryCallsCount, 4)
    }

    func testImportFallsBackToOlderDecryptableFile() async throws {
        signInProvider?._currentUser = TestData.user
        let encrypted = try JSONEncoder().encode(TestData.encryptedAccount)
        let expectedName = "\(TestData.account.address).json"
        googleService?.executeQueryHandler = { query in
            if let list = query as? GTLRDriveQuery_FilesList {
                let files = list.q?.contains("name = 'backupFolder'") == true ?
                    [("folder", "backupFolder")] :
                    [("new-file", expectedName), ("old-file", expectedName)]
                return (GoogleServiceTicketMock(), self.driveList(
                    files,
                    createdTimes: [
                        "new-file": "2026-09-24T10:00:00Z",
                        "old-file": "2026-09-23T10:00:00Z",
                    ]
                ))
            }
            if let get = query as? GTLRDriveQuery_FilesGet {
                let media = GTLRDataObject()
                media.data = get.fileId == "new-file" ? Data("corrupt".utf8) : encrypted
                return (GoogleServiceTicketMock(), media)
            }
            return nil
        }

        let account = try await service?.importBackup(account: TestData.account, password: "1")

        XCTAssertEqual(account?.address, TestData.account.address)
        XCTAssertEqual(googleService?.executeQueryCallsCount, 4)
    }

    func testImportSelectsNewestAcrossDuplicateFolders() async throws {
        signInProvider?._currentUser = TestData.user
        let encrypted = try JSONEncoder().encode(TestData.encryptedAccount)
        let expectedName = "\(TestData.account.address).json"
        googleService?.executeQueryHandler = { query in
            if let list = query as? GTLRDriveQuery_FilesList {
                if list.q?.contains("name = 'backupFolder'") == true {
                    return (GoogleServiceTicketMock(), self.driveList([
                        ("folder-a", "backupFolder"), ("folder-b", "backupFolder"),
                    ]))
                }
                if list.q?.contains("'folder-a' in parents") == true {
                    return (GoogleServiceTicketMock(), self.driveList(
                        [("old-file", expectedName)],
                        createdTimes: ["old-file": "2026-09-23T10:00:00Z"]
                    ))
                }
                XCTAssertTrue(list.q?.contains("'folder-b' in parents") == true)
                return (GoogleServiceTicketMock(), self.driveList(
                    [("new-file", expectedName)],
                    createdTimes: ["new-file": "2026-09-24T10:00:00Z"]
                ))
            }
            if let get = query as? GTLRDriveQuery_FilesGet {
                XCTAssertEqual(get.fileId, "new-file")
                let media = GTLRDataObject()
                media.data = encrypted
                return (GoogleServiceTicketMock(), media)
            }
            return nil
        }

        let account = try await service?.importBackup(account: TestData.account, password: "1")

        XCTAssertEqual(account?.address, TestData.account.address)
        XCTAssertEqual(googleService?.executeQueryCallsCount, 4)
    }

    func testImportRejectsAmbiguousCreationTimeAcrossFolders() async throws {
        signInProvider?._currentUser = TestData.user
        let expectedName = "\(TestData.account.address).json"
        googleService?.executeQueryHandler = { query in
            if let list = query as? GTLRDriveQuery_FilesList {
                if list.q?.contains("name = 'backupFolder'") == true {
                    return (GoogleServiceTicketMock(), self.driveList([
                        ("folder-a", "backupFolder"), ("folder-b", "backupFolder"),
                    ]))
                }
                let id = list.q?.contains("'folder-a' in parents") == true ? "old-file" : "new-file"
                let times = id == "new-file" ? [id: "2026-09-24T10:00:00Z"] : [:]
                return (GoogleServiceTicketMock(), self.driveList(
                    [(id, expectedName)], createdTimes: times
                ))
            }
            if query is GTLRDriveQuery_FilesGet {
                XCTFail("Ambiguous generations must fail before downloading media")
            }
            return nil
        }

        do {
            _ = try await service?.importBackup(account: TestData.account, password: "1")
            XCTFail("Missing creation time must not choose a backup arbitrarily")
        } catch CloudStorageServiceError.incorectJson {
            XCTAssertEqual(googleService?.executeQueryCallsCount, 3)
        }
    }

    func testImportWrongPasswordDoesNotFallBackToOlderGeneration() async throws {
        signInProvider?._currentUser = TestData.user
        encryptionService?.getDecryptedError = CloudStorageServiceError.incorectPassword
        let expectedName = "\(TestData.account.address).json"
        let encrypted = try JSONEncoder().encode(TestData.encryptedAccount)
        var fetchedFileIds: [String] = []
        googleService?.executeQueryHandler = { query in
            if let list = query as? GTLRDriveQuery_FilesList {
                let files = list.q?.contains("name = 'backupFolder'") == true ?
                    [("folder", "backupFolder")] :
                    [("new-file", expectedName), ("old-file", expectedName)]
                return (GoogleServiceTicketMock(), self.driveList(
                    files,
                    createdTimes: [
                        "new-file": "2026-09-24T10:00:00Z",
                        "old-file": "2026-09-23T10:00:00Z",
                    ]
                ))
            }
            if let get = query as? GTLRDriveQuery_FilesGet {
                fetchedFileIds.append(get.fileId ?? "")
                let media = GTLRDataObject()
                media.data = encrypted
                return (GoogleServiceTicketMock(), media)
            }
            return nil
        }

        do {
            _ = try await service?.importBackup(account: TestData.account, password: "old-password")
            XCTFail("Wrong password for newest backup must not restore an older generation")
        } catch CloudStorageServiceError.incorectPassword {
            XCTAssertEqual(fetchedFileIds, ["new-file"])
        }
    }

    func testImportAddressMismatchDoesNotFallBackToOlderGeneration() async throws {
        signInProvider?._currentUser = TestData.user
        let expectedName = "\(TestData.account.address).json"
        var mismatched = TestData.encryptedAccount
        mismatched.address = "different-wallet-address"
        let encrypted = try JSONEncoder().encode(mismatched)
        var fetchedFileIds: [String] = []
        googleService?.executeQueryHandler = { query in
            if let list = query as? GTLRDriveQuery_FilesList {
                let files = list.q?.contains("name = 'backupFolder'") == true ?
                    [("folder", "backupFolder")] :
                    [("new-file", expectedName), ("old-file", expectedName)]
                return (GoogleServiceTicketMock(), self.driveList(
                    files,
                    createdTimes: [
                        "new-file": "2026-09-24T10:00:00Z",
                        "old-file": "2026-09-23T10:00:00Z",
                    ]
                ))
            }
            if let get = query as? GTLRDriveQuery_FilesGet {
                fetchedFileIds.append(get.fileId ?? "")
                let media = GTLRDataObject()
                media.data = encrypted
                return (GoogleServiceTicketMock(), media)
            }
            return nil
        }

        do {
            _ = try await service?.importBackup(account: TestData.account, password: "1")
            XCTFail("Newest backup identity mismatch must not restore an older generation")
        } catch CloudStorageServiceError.readbackMismatch {
            XCTAssertEqual(fetchedFileIds, ["new-file"])
        }
    }

    func testImportRejectsWrongPasswordForEncryptedMaterial() async throws {
        signInProvider?._currentUser = TestData.user
        googleService?.account = TestData.encryptedAccount
        encryptionService?.getDecryptedError = CloudStorageServiceError.incorectPassword

        do {
            _ = try await service?.importBackup(account: TestData.account, password: "wrong")
            XCTFail("Encrypted material must be decrypted before restore succeeds")
        } catch CloudStorageServiceError.incorectPassword {
            // JSON keystore contents require an additional wallet-owned verification.
        }
    }

    func testImportRejectsUndecryptableJsonKeystore() async throws {
        signInProvider?._currentUser = TestData.user
        var jsonOnly = TestData.encryptedAccount
        jsonOnly.backupAccountType = ["json"]
        jsonOnly.encryptedSubstrateDerivationPath = nil
        jsonOnly.encryptedSeed = nil
        jsonOnly.json = OpenBackupAccount.Json(substrateJson: TestData.substrateJson)
        googleService?.account = jsonOnly

        do {
            _ = try await service?.importBackup(account: TestData.account, password: "wrong-password")
            XCTFail("A JSON keystore must decrypt before restore succeeds")
        } catch CloudStorageServiceError.incorectPassword {
            // Drive byte fidelity alone does not prove a usable JSON keystore.
        }
    }

    func testImportRejectsTruncatedJsonKeystore() async throws {
        signInProvider?._currentUser = TestData.user
        // A complete, valid scrypt header (N=2, p=1, r=1), with no nonce or ciphertext.
        let header = Data(repeating: 0, count: 32) + Data([2, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0])
        googleService?.account = try jsonOnlyBackup(encoded: header.base64EncodedString())

        do {
            _ = try await service?.importBackup(account: TestData.account, password: "1")
            XCTFail("A truncated JSON keystore must fail without terminating the process")
        } catch CloudStorageServiceError.incorectJson {
            // Structurally malformed bytes may fall back to an older generation.
        }
    }

    func testImportMalformedNewestJsonKeystoreFallsBackToOlderGeneration() async throws {
        signInProvider?._currentUser = TestData.user
        let header = Data(repeating: 0, count: 32) + Data([2, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0])
        let cases: [(encoded: String, encrypted: Bool)] = [
            (header.base64EncodedString(), true),
            ("not base64", true),
            (Data([0]).base64EncodedString(), false),
            (KeystoreConstants.pkcs8Header.base64EncodedString(), false),
        ]
        let oldData = try JSONEncoder().encode(TestData.encryptedAccount)
        let expectedName = "\(TestData.account.address).json"
        for malformed in cases {
            let newData = try JSONEncoder().encode(jsonOnlyBackup(
                encoded: malformed.encoded, encrypted: malformed.encrypted
            ))
            var fetchedFileIds: [String] = []
            googleService?.executeQueryHandler = { query in
                if let list = query as? GTLRDriveQuery_FilesList {
                    let files = list.q?.contains("name = 'backupFolder'") == true ?
                        [("folder", "backupFolder")] :
                        [("new-file", expectedName), ("old-file", expectedName)]
                    return (GoogleServiceTicketMock(), self.driveList(
                        files,
                        createdTimes: [
                            "new-file": "2026-09-24T10:00:00Z",
                            "old-file": "2026-09-23T10:00:00Z",
                        ]
                    ))
                }
                if let get = query as? GTLRDriveQuery_FilesGet {
                    fetchedFileIds.append(get.fileId ?? "")
                    let media = GTLRDataObject()
                    media.data = get.fileId == "new-file" ? newData : oldData
                    return (GoogleServiceTicketMock(), media)
                }
                return nil
            }

            let account = try await service?.importBackup(account: TestData.account, password: "1")
            XCTAssertEqual(account?.address, TestData.account.address)
            XCTAssertEqual(fetchedFileIds, ["new-file", "old-file"])
        }
    }

    func testImportUnauthenticatedNewestJsonKeystoreDoesNotFallBack() async throws {
        signInProvider?._currentUser = TestData.user
        let header = Data(repeating: 0, count: 32) + Data([2, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0])
        let frame = header + Data(repeating: 0, count: 24 + 16)
        let newData = try JSONEncoder().encode(jsonOnlyBackup(encoded: frame.base64EncodedString()))
        let oldData = try JSONEncoder().encode(TestData.encryptedAccount)
        let expectedName = "\(TestData.account.address).json"
        var fetchedFileIds: [String] = []
        googleService?.executeQueryHandler = { query in
            if let list = query as? GTLRDriveQuery_FilesList {
                let files = list.q?.contains("name = 'backupFolder'") == true ?
                    [("folder", "backupFolder")] :
                    [("new-file", expectedName), ("old-file", expectedName)]
                return (GoogleServiceTicketMock(), self.driveList(
                    files,
                    createdTimes: [
                        "new-file": "2026-09-24T10:00:00Z",
                        "old-file": "2026-09-23T10:00:00Z",
                    ]
                ))
            }
            if let get = query as? GTLRDriveQuery_FilesGet {
                fetchedFileIds.append(get.fileId ?? "")
                let media = GTLRDataObject()
                media.data = get.fileId == "new-file" ? newData : oldData
                return (GoogleServiceTicketMock(), media)
            }
            return nil
        }

        do {
            _ = try await service?.importBackup(account: TestData.account, password: "wrong")
            XCTFail("Authentication failure must not restore an older backup")
        } catch CloudStorageServiceError.incorectPassword {
            XCTAssertEqual(fetchedFileIds, ["new-file"])
        }
    }

    private func jsonOnlyBackup(
        encoded: String,
        encrypted: Bool = true
    ) throws -> EcryptedBackupAccount {
        var definition = try XCTUnwrap(JSONSerialization.jsonObject(
            with: Data(TestData.substrateJson.utf8)
        ) as? [String: Any])
        definition["encoded"] = encoded
        if !encrypted {
            var encoding = try XCTUnwrap(definition["encoding"] as? [String: Any])
            encoding["type"] = [String]()
            definition["encoding"] = encoding
        }
        var account = TestData.encryptedAccount
        account.backupAccountType = ["json"]
        account.encryptedMnemonicPhrase = nil
        account.encryptedSubstrateDerivationPath = nil
        account.encryptedEthDerivationPath = nil
        account.encryptedSeed = nil
        account.json = try OpenBackupAccount.Json(substrateJson: String(
            decoding: JSONSerialization.data(withJSONObject: definition), as: UTF8.self
        ))
        return account
    }

    func testImportBackupAccount() async throws {
        // arrange
        signInProvider?._currentUser = TestData.user
        googleService?.account = TestData.encryptedAccount

        // act
        let account = try await service?.importBackup(account: TestData.account, password: "1")

        // assert
        XCTAssertEqual(account?.name, TestData.account.name)
        XCTAssertEqual(account?.address, TestData.account.address)
        XCTAssertEqual(account?.cryptoType, TestData.account.cryptoType)
        XCTAssertEqual(account?.ethDerivationPath, TestData.account.ethDerivationPath)
        XCTAssertEqual(account?.backupAccountType, TestData.account.backupAccountType)
        XCTAssertEqual(account?.json, TestData.account.json)
    }

    func testImportBackupAccountWithError() async throws {
        // arrange
        signInProvider?._currentUser = TestData.user
        googleService?.account = TestData.encryptedAccount

        // act
        do {
            let account = try await service?.importBackup(
                account: TestData.emptyAccount,
                password: "1"
            )
        } catch {
            // assert
            XCTAssertEqual(
                error.localizedDescription,
                CloudStorageServiceError.notFound.localizedDescription
            )
        }
    }

    func testDeleteBackupAccount() async throws {
        // arrange
        signInProvider?._currentUser = TestData.user

        // act
        try await service?.deleteBackup(account: TestData.account)

        // assert
        XCTAssertEqual(googleService?.setAuthorizerCallsCount, 2)
        XCTAssertEqual(googleService?.executeQueryCallsCount, 5)

        XCTAssertTrue(googleService?.setAuthorizerCalled ?? false)
        XCTAssertTrue(googleService?.executeQueryCalled ?? false)
    }

    func testDeleteRemovesAllMobileGenerationsAcrossFoldersButNotExtensionFile() async throws {
        signInProvider?._currentUser = TestData.user
        let expectedName = "\(TestData.account.address).json"
        var deletedFileIds: [String] = []
        googleService?.executeQueryHandler = { query in
            if let list = query as? GTLRDriveQuery_FilesList {
                if list.q?.contains("name = 'backupFolder'") == true {
                    return (GoogleServiceTicketMock(), self.driveList([
                        ("folder-a", "backupFolder"), ("folder-b", "backupFolder"),
                    ]))
                }
                XCTAssertTrue(list.q?.contains("'folder-a' in parents") == true ||
                    list.q?.contains("'folder-b' in parents") == true)
                if list.q?.contains("'folder-a' in parents") == true {
                    return (GoogleServiceTicketMock(), self.driveList([
                        ("old-file", expectedName),
                        ("unrelated-file", "prefix-\(expectedName)"),
                    ], createdTimes: ["old-file": "2026-09-23T10:00:00Z"]))
                }
                return (GoogleServiceTicketMock(), self.driveList([
                    ("new-file", expectedName),
                ], createdTimes: ["new-file": "2026-09-24T10:00:00Z"]))
            }
            if let deletion = query as? GTLRDriveQuery_FilesDelete {
                deletedFileIds.append(deletion.fileId ?? "")
                return (GoogleServiceTicketMock(), nil)
            }
            return nil
        }

        try await service?.deleteBackup(account: TestData.account)

        XCTAssertEqual(deletedFileIds, ["old-file", "new-file"])
    }

    func testDeleteRejectsTiedCreationTimesBeforeRemovingAnyFile() async throws {
        signInProvider?._currentUser = TestData.user
        let expectedName = "\(TestData.account.address).json"
        var deletedFileIds: [String] = []
        googleService?.executeQueryHandler = { query in
            if let list = query as? GTLRDriveQuery_FilesList {
                if list.q?.contains("name = 'backupFolder'") == true {
                    return (GoogleServiceTicketMock(), self.driveList([
                        ("folder-a", "backupFolder"), ("folder-b", "backupFolder"),
                    ]))
                }
                let id = list.q?.contains("'folder-a' in parents") == true ? "file-a" : "file-b"
                return (GoogleServiceTicketMock(), self.driveList(
                    [(id, expectedName)],
                    createdTimes: [id: "2026-09-24T10:00:00Z"]
                ))
            }
            if let deletion = query as? GTLRDriveQuery_FilesDelete {
                deletedFileIds.append(deletion.fileId ?? "")
            }
            return nil
        }

        do {
            try await service?.deleteBackup(account: TestData.account)
            XCTFail("Tied creation times cannot establish a safe deletion order")
        } catch CloudStorageServiceError.incorectJson {
            XCTAssertTrue(deletedFileIds.isEmpty)
        }
    }

    func testDeleteFailureKeepsNewestGeneration() async throws {
        signInProvider?._currentUser = TestData.user
        let expectedName = "\(TestData.account.address).json"
        var deletedFileIds: [String] = []
        googleService?.executeQueryHandler = { query in
            if let list = query as? GTLRDriveQuery_FilesList {
                if list.q?.contains("name = 'backupFolder'") == true {
                    return (GoogleServiceTicketMock(), self.driveList([("folder", "backupFolder")]))
                }
                return (GoogleServiceTicketMock(), self.driveList(
                    [("new-file", expectedName), ("old-file", expectedName)],
                    createdTimes: [
                        "new-file": "2026-09-24T10:00:00Z",
                        "old-file": "2026-09-23T10:00:00Z",
                    ]
                ))
            }
            if let deletion = query as? GTLRDriveQuery_FilesDelete {
                deletedFileIds.append(deletion.fileId ?? "")
                if deletion.fileId == "new-file" {
                    throw CloudStorageServiceError.notAuthorized
                }
                return (GoogleServiceTicketMock(), nil)
            }
            return nil
        }

        do {
            try await service?.deleteBackup(account: TestData.account)
            XCTFail("A partial deletion must surface the failure")
        } catch CloudStorageServiceError.notAuthorized {
            XCTAssertEqual(deletedFileIds, ["old-file", "new-file"])
        }
    }

    func testDeleteBackupAccountWithError() async throws {
        // arrange
        signInProvider?._currentUser = TestData.user

        // act
        do {
            try await service?.deleteBackup(account: TestData.emptyAccount)
        } catch {
            // assert
            XCTAssertEqual(
                error.localizedDescription,
                FearlessExtensionError.backupNotFound.localizedDescription
            )
        }
    }

    func testDisconnect() {
        // act
        service?.disconnect()

        // assert
        XCTAssertEqual(signInProvider?.signOutCallsCount, 1)
        XCTAssertEqual(signInProvider?.disconnectCompletionCallsCount, 1)

        XCTAssertTrue(signInProvider?.signOutCalled ?? false)
        XCTAssertTrue(signInProvider?.disconnectCompletionCalled ?? false)
    }
}

extension CloudStorageServiceTests {
    enum TestData {
        static let user = GIDGoogleUser()

        static let substrateJson = """
        {\"address\":\"cnSNFyYFzPPJWm1yKjZCKZnGhhrZWWx1Mme1gw64YvjJhNGoJ\",\"encoded\":\"AAUbK8HDAE7Mw26rox6dktexv9pG5MRk\\/WtCJFtV2+kAgAAAAQAAAAgAAACivZKIFh9rMwauWG97MJ0ONwPg6eOpXNygK6X9RQfKMPvETRAfpHbRJp42LKEeWDNczqKaxltMj3yeMUi9kOYIz1sXMt7g7PC7aHUvSsF2G8nzV+XrNpC7nc8s+ty1OmVeKJWsSACfNj3OW9gxesmAtpfSrWx2ppSviKwvU1SKNYPfq+rxFCG+sXx4lggOFouAmT5iaPTL9fck\\/1vI\",\"encoding\":{\"content\":[\"pkcs8\",\"sr25519\"],\"type\":[\"scrypt\",\"xsalsa20-poly1305\"],\"version\":\"3\"},\"meta\":{\"genesisHash\":\"0xded5a658e6ff2c82ce640caf8910ea2bb700aad5511ec7c3014cc7c256f5d956\",\"name\":\"chop\",\"whenCreated\":1706609064}}
        """

        static let substrateSeed = """
        0ffea7239c86f2c57976bb2ae65f0fe183ad40b5450edd2c0f2610aab80e9ae70080000001000000080000009f92ff8b19a2fc6eb7b68b746d9c6b6a21710d82b13704e62a7b90e402b8cd879b4f859f7da243bcc9f9674435e08fcd1a3562e500b99d3e40508bdd34e54819e3b79153097995f687ad3180852a3b1f05a657919ec8dcf2f0f0ed88693e0a263aa7ec0ff1106763e842
        """

        static let account = OpenBackupAccount(
            name: "chop",
            address: "cnSNFyYFzPPJWm1yKjZCKZnGhhrZWWx1Mme1gw64YvjJhNGoJ",
            cryptoType: "SR25519",
            substrateDerivationPath: nil,
            ethDerivationPath: nil,
            backupAccountType: [.seed],
            json: OpenBackupAccount.Json(),
            encryptedSeed: OpenBackupAccount.Seed(substrateSeed: substrateSeed)
        )

        static let encryptedAccount = EcryptedBackupAccount(
            name: "chop",
            address: "cnSNFyYFzPPJWm1yKjZCKZnGhhrZWWx1Mme1gw64YvjJhNGoJ",
            encryptedMnemonicPhrase: nil,
            encryptedSubstrateDerivationPath: "5944fbdce78478ef92858817b176fe0b5b884e9c8652de8e10061f0680f83c3100800000010000000800000012e34d41a1843fe84e627672c688150b2ab19c12e7d6b77dab91457f3e8f06a1ca66218604f14691",
            encryptedEthDerivationPath: nil,
            cryptoType: "SR25519",
            backupAccountType: ["seed"],
            json: OpenBackupAccount.Json(),
            encryptedSeed: OpenBackupAccount
                .Seed(substrateSeed: substrateSeed)
        )

        static let emptyAccount = OpenBackupAccount(address: "")
    }

    func getURL() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(TestData.encryptedAccount.address)")
            .appendingPathExtension("json")
        let data = try JSONEncoder().encode(TestData.encryptedAccount)
        try data.write(to: url)
        return url
    }

    private func driveList(
        _ entries: [(String, String)],
        createdTimes: [String: String] = [:]
    ) -> GTLRDrive_FileList {
        let list = GTLRDrive_FileList()
        list.files = entries.map { identifier, name in
            let file = GTLRDrive_File()
            file.identifier = identifier
            file.name = name
            if let timestamp = createdTimes[identifier] {
                file.createdTime = GTLRDateTime(rfc3339String: timestamp)
            }
            return file
        }
        return list
    }
}
