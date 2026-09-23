import Foundation
import TweetNacl

public enum Mnemonic {
    public static let words = String.englishMnemonics
    
    /**
     Generate new mnemonic
     
     - Parameter wordsCount: number of words to generate
     - Parameter password: mnemonic password
     - returns: mnemonic string
     */
    public static func mnemonicNew(wordsCount: Int = 24, password: String = "") -> [String] {
        var mnemonicArray: [String] = []
        
        while true {
            mnemonicArray = []
            let rnd = [Int](repeating: 0, count: wordsCount).map({ _ in Int.random(in: 0..<Int.max) })
            for i in 0..<wordsCount {
                mnemonicArray.append(words[rnd[i] % (words.count - 1)])
            }
            
            if password.count > 0 {
                if !isPasswordNeeded(mnemonicArray: mnemonicArray) {
                    continue
                }
            }
            
            if !isBasicSeed(entropy: mnemonicToEntropy(mnemonicArray: mnemonicArray, password: password)) {
                continue
            }
            
            break
        }
        
        return mnemonicArray
    }
    
    /**
     Validate Mnemonic
     
     - Parameter mnemonicArray: mnemonic array
     - Parameter password: mnemonic password
     - returns: true for valid mnemonic
     */
    public static func mnemonicValidate(mnemonicArray: [String], password: String = "") -> Bool {
        let mnemonicArray = normalizeMnemonic(src: mnemonicArray)
        
        for word in mnemonicArray {
            if !words.contains(word) {
                return false
            }
        }
        
        if password.count > 0 {
            if !isPasswordNeeded(mnemonicArray: mnemonicArray) {
                return false
            }
        }
        
        return isBasicSeed(entropy: mnemonicToEntropy(mnemonicArray: mnemonicArray, password: password))
    }
    
    /**
     Convert mnemonic to entropy
     
     - Parameter mnemonicArray: mnemonic array
     - Parameter password: mnemonic password
     - returns: 64 byte entropy
     */
    public static func mnemonicToEntropy(mnemonicArray: [String], password: String = "") -> Data {
        return hmacSha512(phrase: mnemonicArray.joined(separator: " "), password: password)
    }
    
    /**
     Convert mnemonic to seed
     
     - Parameter mnemonicArray: mnemonic array
     - Parameter password: mnemonic password
     - returns: 64 byte seed
     */
    public static func mnemonicToSeed(mnemonicArray: [String], password: String = "") -> Data {
        let entropy = mnemonicToEntropy(mnemonicArray: mnemonicArray, password: password)
        
        let salt = "TON default seed"
        let saltData = Data(salt.utf8)
        
        return Data(pbkdf2Sha512(phrase: entropy, salt: saltData))
    }
    
    /**
     Convert mnemonic to HD seed
     
     - Parameter mnemonicArray: mnemonic array
     - Parameter password: mnemonic password
     - returns: 64 byte seed
     */
    public static func mnemonicToHDSeed(mnemonicArray: [String], password: String = "") -> Data {
        let entropy = mnemonicToEntropy(mnemonicArray: mnemonicArray, password: password)
        
        let salt = "TON HD Keys seed"
        let saltData = Data(salt.utf8)
        
        return Data(pbkdf2Sha512(phrase: entropy, salt: saltData))
    }
    
    public static func isPasswordNeeded(mnemonicArray: [String]) -> Bool {
        let passlessEntropy = mnemonicToEntropy(mnemonicArray: mnemonicArray, password: "")
        return isPasswordSeed(entropy: passlessEntropy) && !isBasicSeed(entropy: passlessEntropy)
    }
    
    public static func isBasicSeed(entropy: Data) -> Bool {
        let salt = "TON seed version"
        let saltData = Data(salt.utf8)
        let seed = pbkdf2Sha512(phrase: entropy, salt: saltData, iterations: max(1, pbkdf2Sha512Iterations / 256))
        
        return seed[0] == 0
    }
        
    public static func isPasswordSeed(entropy: Data) -> Bool {
        let salt = "TON fast seed version"
        let saltData = Data(salt.utf8)
        let seed = pbkdf2Sha512(phrase: entropy, salt: saltData, iterations: 1)
        
        return seed[0] == 1
    }
    
    public static func normalizeMnemonic(src: [String]) -> [String] {
        return src.map({ $0.lowercased() })
    }
    
    /**
     Extract private key from mnemonic
     
     - Parameter mnemonicArray: mnemonic array
     - Parameter password: mnemonic password
     - returns: KeyPair
     */
    public static func mnemonicToPrivateKey(mnemonicArray: [String], password: String = "") throws -> KeyPair {
        let mnemonicArray = normalizeMnemonic(src: mnemonicArray)
        let seed = mnemonicToSeed(mnemonicArray: mnemonicArray, password: password)[0..<32]
        
        do {
            let keyPair = try TweetNacl.NaclSign.KeyPair.keyPair(fromSeed: seed)
            return KeyPair(publicKey: .init(data: keyPair.publicKey), privateKey: .init(data: keyPair.secretKey))
            
        } catch {
            throw error
        }
    }
}
