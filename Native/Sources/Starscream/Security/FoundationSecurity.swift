//////////////////////////////////////////////////////////////////////////////////////////////////
//
//  FoundationSecurity.swift
//  Starscream
//
//  Created by Dalton Cherry on 3/16/19.
//  Copyright © 2019 Vluxe. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//
//////////////////////////////////////////////////////////////////////////////////////////////////

import Foundation
import CommonCrypto

public enum FoundationSecurityError: Error {
    case invalidRequest
}

public class FoundationSecurity  {
    var allowSelfSigned = false
    
    public init(allowSelfSigned: Bool = false) {
        self.allowSelfSigned = allowSelfSigned
    }
    
    
}

extension FoundationSecurity: CertificatePinning {
    public func evaluateTrust(trust: SecTrust, domain: String?, completion: ((PinningState) -> ())) {
        if allowSelfSigned {
            completion(.success)
            return
        }
        
        SecTrustSetPolicies(trust, SecPolicyCreateSSL(true, domain as NSString?))
        
        handleSecurityTrust(trust: trust, completion: completion)
    }
    
    private func handleSecurityTrust(trust: SecTrust, completion: ((PinningState) -> ())) {
        if #available(iOS 12.0, OSX 10.14, watchOS 5.0, tvOS 12.0, *) {
            var error: CFError?
            if SecTrustEvaluateWithError(trust, &error) {
                completion(.success)
            } else {
                completion(.failed(error))
            }
        } else {
            handleOldSecurityTrust(trust: trust, completion: completion)
        }
    }
    
    private func handleOldSecurityTrust(trust: SecTrust, completion: ((PinningState) -> ())) {
        var result: SecTrustResultType = .unspecified
        SecTrustEvaluate(trust, &result)
        if result == .unspecified || result == .proceed {
            completion(.success)
        } else {
            let e = CFErrorCreate(kCFAllocatorDefault, "FoundationSecurityError" as NSString?, Int(result.rawValue), nil)
            completion(.failed(e))
        }
    }
}

extension FoundationSecurity: HeaderValidator {
    public func validate(headers: [String: String], key: String) -> Error? {
        // HTTP field names are case-insensitive. A missing or ambiguous
        // accept header must never establish a WebSocket connection.
        func field(_ name: String) -> String? {
            let values = headers.filter { $0.key.caseInsensitiveCompare(name) == .orderedSame }
            guard values.count == 1 else { return nil }
            return values.first?.value.trimmingCharacters(in: .whitespaces)
        }
        let expected = "\(key)258EAFA5-E914-47DA-95CA-C5AB0DC85B11".sha1Base64()
        let connectionTokens = field(HTTPWSHeader.connectionName)?.split(separator: ",").map {
            $0.trimmingCharacters(in: .whitespaces).lowercased()
        } ?? []
        guard field(HTTPWSHeader.acceptName) == expected,
              field(HTTPWSHeader.upgradeName)?.lowercased() == HTTPWSHeader.upgradeValue,
              connectionTokens.contains("upgrade") else {
            return WSError(type: .securityError, message: "invalid WebSocket upgrade response", code: SecurityErrorCode.acceptFailed.rawValue)
        }
        return nil
    }
}

private extension String {
    func sha1Base64() -> String {
        let data = self.data(using: .utf8)!
        let pointer = data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) -> [UInt8] in
            var digest = [UInt8](repeating: 0, count:Int(CC_SHA1_DIGEST_LENGTH))
            CC_SHA1(bytes.baseAddress, CC_LONG(data.count), &digest)
            return digest
        }
        return Data(pointer).base64EncodedString()
    }
}
