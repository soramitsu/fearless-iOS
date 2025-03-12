//
//  ErrorViewModelFactory.swift
//  fearless
//
//  Created by alex on 05.03.2025.
//  Copyright © 2025 Soramitsu. All rights reserved.
//

import Web3
import Foundation

protocol ErrorViewModelFactory {
    func buildViewModel(
        error: Error,
        actionTitle: String?,
        actionHandler: (() -> Void)?,
        locale: Locale
    ) -> ErrorViewModel
}

extension ErrorViewModelFactory {
    func buildViewModel(
        error: Error,
        actionTitle: String?,
        actionHandler: (() -> Void)?,
        locale: Locale
    ) -> ErrorViewModel {
        var title: String
        var message: String
        
        if let rpcError = error as? RPCResponse<EthereumQuantity>.Error {
            title = R.string.localizable.commonImportant(
                preferredLanguages: locale.rLanguages
            )
            message = rpcError.message
            
        } else if let rpcError = error as? RPCResponse<EthereumData>.Error {
            title = R.string.localizable.commonImportant(
                preferredLanguages: locale.rLanguages
            )
            message = rpcError.message
        } else {
            title = R.string.localizable.commonImportant(
                preferredLanguages: locale.rLanguages
            )
            message = error.localizedDescription
            
        }
        
        return ErrorViewModel(
            title: title,
            message: message,
            actionTitle: actionTitle,
            actionHandler: actionHandler
        )
    }
}
