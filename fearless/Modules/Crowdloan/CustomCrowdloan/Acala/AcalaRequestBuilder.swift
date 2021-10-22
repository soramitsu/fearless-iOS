//
//  AcalaRequestBuilder.swift
//  fearless
//
//  Created by Ярослав Екимов on 22.10.2021.
//  Copyright © 2021 Soramitsu. All rights reserved.
//

import Foundation

final class AcalaHTTPRequestBuilder: HTTPRequestBuilder {
    #if F_RELEASE
        static let host: String = "crowdloan.aca-dev.network"
    #else
        static let host: String = "crowdloan.aca-dev.network"
    #endif

    init() {
        super.init(host: AcalaHTTPRequestBuilder.host)
    }
}
