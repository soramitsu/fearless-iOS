//
//  CDMetaAccountMigrationPolicy.swift
//  fearless
//
//  Created by Soramitsu on 04.11.2024.
//  Copyright © 2024 Soramitsu. All rights reserved.
//

import CoreData

class CDMetaAccountMigrationPolicy: NSEntityMigrationPolicy {
    override func createDestinationInstances(
        forSource sInstance: NSManagedObject,
        in mapping: NSEntityMapping,
        manager: NSMigrationManager
    ) throws {
        try super.createDestinationInstances(forSource: sInstance, in: mapping, manager: manager)

        if let destination = manager.destinationInstances(
            forEntityMappingName: mapping.name,
            sourceInstances: [sInstance]
        ).first {
            destination.setValue(nil, forKey: "tonAddress")
            destination.setValue(nil, forKey: "tonContractVersion")
            destination.setValue(nil, forKey: "tonPublicKey")

            if destination.value(forKey: "substrateAccountId") == nil {
                destination.setValue(nil, forKey: "substrateAccountId")
            }
            if destination.value(forKey: "substrateCryptoType") == nil {
                destination.setValue(0, forKey: "substrateCryptoType")
            }
            if destination.value(forKey: "substratePublicKey") == nil {
                destination.setValue(nil, forKey: "substratePublicKey")
            }
//            let substrateAccountId = destination.value(forKey: "substrateAccountId")
//            destination.setValue(substrateAccountId, forKey: "substrateAccountId")
//
//            let substrateCryptoType = destination.value(forKey: "substrateCryptoType")
//            destination.setValue(substrateAccountId, forKey: "substrateCryptoType")
//
//            let substratePublicKey = destination.value(forKey: "substratePublicKey")
//            destination.setValue(substrateAccountId, forKey: "substratePublicKey")
        }
    }
}
