//
//  AcalaBonusServiceTests.swift
//  fearlessTests
import XCTest
@testable import fearless
import SoraKeystore

class AcalaBonusServiceTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }


    func testReferralCodeSaving() throws {
        let expectedReferralCode = "test"
        
        let service: AcalaSpecificBonusServiceProtocol = self.buildAcalaBonusServiceObject()
        service.save(referralCode: expectedReferralCode) { result in
            switch result {
            case .success(<#T##Void#>)
            }
        }
    }


}

extension AcalaBonusServiceTests {
    
    func buildAcalaBonusServiceObject() -> AcalaSpecificBonusServiceProtocol {
        let keychain = InMemoryKeychain()
        let settings = InMemorySettingsManager()
        
        let signer: SigningWrapperProtocol = SigningWrapper(keystore: keychain,
                                                            settings: settings)
        let accountAddress = settings.selectedAccount!.address
        let operationManager = OperationManagerFacade.sharedManager

        return AcalaBonusService(address: accountAddress,
                                        chain: .westend,
                                        signingWrapper: signer,
                                        operationManager: operationManager)
        
    }
}
