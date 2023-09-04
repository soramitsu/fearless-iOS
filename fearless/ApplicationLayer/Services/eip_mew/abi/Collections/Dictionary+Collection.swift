//
//  File.swift
//
//
//  Created by Mikhail Nikanorov on 9/13/21.
//

import Foundation

extension Dictionary where Key == String, Value == AnyObject {
    func inputs(for _: Method) -> [ABI.ContractCollection.InParameters: AnyObject]? {
        let result: [ABI.ContractCollection.InParameters: AnyObject] = reduce([:]) { result, value in
            guard let inParameter = ABI.ContractCollection.InParameters(rawValue: value.key) else {
                return result
            }
            var result = result
            result[inParameter] = value.value
            return result
        }
        guard !result.isEmpty else { return nil }
        return result
    }
}
