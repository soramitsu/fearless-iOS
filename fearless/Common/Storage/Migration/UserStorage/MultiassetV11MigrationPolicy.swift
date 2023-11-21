//
//  MultiassetV11MigrationPolicy.swift
//  fearless
//
//  Created by Soramitsu on 09.11.2023.
//  Copyright © 2023 Soramitsu. All rights reserved.
//

import Foundation
import CoreData

class MultiassetV11MigrationPolicy: NSEntityMigrationPolicy {
    override func createDestinationInstances(
        forSource wallet: NSManagedObject,
        in mapping: NSEntityMapping,
        manager: NSMigrationManager
    ) throws {
        try super.createDestinationInstances(forSource: wallet, in: mapping, manager: manager)

        let chainIdForFilter = wallet.value(forKey: "chainIdForFilter") as? String

        guard let updatedWallet = manager.destinationInstances(
            forEntityMappingName: mapping.name,
            sourceInstances: [wallet]
        ).first else {
            return
        }

        updatedWallet.setValue(chainIdForFilter, forKey: "networkManagmentFilter")
        updatedWallet.setValue([String](), forKey: "favouriteChainIds")

        manager.associate(sourceInstance: wallet, withDestinationInstance: updatedWallet, for: mapping)
    }
}
