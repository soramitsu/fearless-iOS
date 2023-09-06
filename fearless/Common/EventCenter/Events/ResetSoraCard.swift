//
//  ResetSoraCard.swift
//  fearless
//
//  Created by Денис Лебедько on 06.09.2023.
//  Copyright © 2023 Soramitsu. All rights reserved.
//

import Foundation

struct ResetSoraCard: EventProtocol {
    func accept(visitor: EventVisitorProtocol) {
        visitor.processResetSoraCard()
    }
}
