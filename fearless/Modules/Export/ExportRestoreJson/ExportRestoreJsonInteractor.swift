//
//  ExportRestoreJsonInteractor.swift
//  fearless
//
//  Created by Soramitsu on 18.07.2023.
//  Copyright © 2023 Soramitsu. All rights reserved.
//

import Foundation
import UIKit
import IrohaCrypto

final class ExportRestoreJsonInteractor {
    private let settings: SelectedWalletSettings
    private let wallet: MetaAccountModel
    private let eventCenter: EventCenterProtocol

    init(
        settings: SelectedWalletSettings,
        wallet: MetaAccountModel,
        eventCenter: EventCenterProtocol
    ) {
        self.settings = settings
        self.wallet = wallet
        self.eventCenter = eventCenter
    }
}

extension ExportRestoreJsonInteractor: ExportRestoreJsonInteractorProtocol {
    func walletDidBackuped() {
        let backupedWallet = wallet.replacingIsBackuped(true)
        settings.save(value: backupedWallet)
        let event = MetaAccountModelChangedEvent(account: backupedWallet)
        eventCenter.notify(with: event)
    }
}
