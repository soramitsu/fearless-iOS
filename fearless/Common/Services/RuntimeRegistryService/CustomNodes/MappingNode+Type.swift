import Foundation

extension MappingNode {
   static var unappliedSlashes: MappingNode {
        MappingNode(typeName: "UnappliedSlash<AccountId, BalanceOf>",
                    typeMapping: [
                        NamedType(name: "validator", type: "AccountId"),
                        NamedType(name: "own", type: "Balance"),
                        NamedType(name: "others", type: "Vec<UnappliedSlashOther>"),
                        NamedType(name: "reporters", type: "Vec<AccountId>"),
                        NamedType(name: "payout", type: "Balance")
                    ])
    }
}
