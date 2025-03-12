//
//  CrossChainSwapViewType.swift
//  fearless
//
//  Created by alex on 06.03.2025.
//  Copyright © 2025 Soramitsu. All rights reserved.
//

import Foundation

enum CrossChainSwapViewType {
    case undefined
    case swap
    case bridge
    
    init(isCrossChainSwap: Bool?) {
        guard let isCrossChainSwap else {
            self = .undefined
            return
        }
        
        self = isCrossChainSwap ? .bridge : .swap
    }
    
    func title(for locale: Locale) -> String {
        switch self {
        case .bridge: return R.string.localizable.okxBridgeTitle(preferredLanguages: locale.rLanguages)
        case .swap: return R.string.localizable.okxSwapTitle(preferredLanguages: locale.rLanguages)
        case .undefined: return ""
        }
    }
}
