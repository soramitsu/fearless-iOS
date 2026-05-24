//
//  ABI+Collection.swift
//  MEWwalletKit
//
//  Created by Mikhail Nikanorov on 9/13/21.
//  Copyright © 2021 MyEtherWallet Inc. All rights reserved.
//

import Foundation

protocol Contract {
    var methods: [ABI.ContractCollection.MethodName: Method] { get }
}

struct Method {
    let name: ABI.ContractCollection.MethodName
    let `in`: [ABI.Element.InOut]
    let out: [ABI.Element.InOut]
}

extension ABI {
    internal enum ContractCollection {
        internal enum MethodName: String {
            case transfer
        }

        internal enum InParameters: ABI.Element.InOutName {
            case to
            case value
        }

        internal enum OutParameters: ABI.Element.InOutName {
            case success
        }

        // MARK: - Static

        static let erc20Transfer = Method(
            name: .transfer,
            in: [
                .init(name: ABI.ContractCollection.InParameters.to.rawValue, type: .address),
                .init(name: ABI.ContractCollection.InParameters.value.rawValue, type: .uint(bits: 256))
            ],
            out: [
                .init(name: ABI.ContractCollection.OutParameters.success.rawValue, type: .bool)
            ]
        )

        static var erc20: Contract { ERC20() }
    }

    // MARK: - Private

    // MARK: - ERC-20

    private struct ERC20: Contract {
        var methods: [ABI.ContractCollection.MethodName: Method] {
            [
                .transfer: ABI.ContractCollection.erc20Transfer
            ]
        }
    }
}

extension ABI.Element.Function {
    static var erc20transfer: ABI.Element.Function {
        let erc20transfer = ABI.ContractCollection.erc20Transfer
        return .init(
            name: erc20transfer.name.rawValue,
            inputs: erc20transfer.in,
            outputs: erc20transfer.out,
            constant: false,
            payable: false
        )
    }
}
