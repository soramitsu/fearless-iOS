//
//  MetaAccountOperationFactoryTests.swift
//  fearlessTests
//
//  Created by alex on 23.03.2022.
//  Copyright © 2022 Soramitsu. All rights reserved.
//

import XCTest
@testable import fearless
import SoraKeystore
import IrohaCrypto

class MetaAccountOperationFactoryTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testCreateSubstrateAccountFromMnemonic() throws {
        let keystore = InMemoryKeychain()
        let metaAccountOperationFactory = MetaAccountOperationFactory(keystore: keystore)
        
        let mnemonicPhrase = "mistake lonely edit matrix jump airport drama supply possible acoustic pause gas"
        guard let mnemonic = try? IRMnemonicCreator()
            .mnemonic(fromList: mnemonicPhrase)
        else {
            XCTFail()
            return
        }
        
        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = 1
        
        let request = MetaAccountCreationRequest(username: "1",
                                                 substrateDerivationPath: "",
                                                 substrateCryptoType: .sr25519,
                                                 ethereumDerivationPath: "")
        
        let operation = metaAccountOperationFactory.newMetaAccountOperation(request: request,
                                                                            mnemonic: mnemonic)
        
        let operationQueue = OperationQueue()
        operationQueue.addOperation(operation)
        
        operation.completionBlock = {
            do {
                let result = try operation.extractNoCancellableResultData()
                result.substratePublicKey
            } catch {
                XCTFail(error.localizedDescription)
            }
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 5, handler: nil)
        
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
