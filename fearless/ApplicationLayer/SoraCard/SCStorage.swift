import Foundation

 final class SCStorage {
     static let shared = SCStorage()

     private enum Key: String {
         case kycId = "SCKycId"
         case refreshToken = "SCRefreshToken"
         case accessToken = "SCAccessToken"
     }

     func kycId() -> String? {
         UserDefaults.standard.string(forKey: Key.kycId.rawValue)
     }

     func add(kycId: String?) {
         UserDefaults.standard.set(kycId, forKey: Key.kycId.rawValue)
     }

     func accessToken() -> String? {
         UserDefaults.standard.string(forKey: Key.accessToken.rawValue)
     }

     func add(accessToken: String) {
         UserDefaults.standard.set(accessToken, forKey: Key.accessToken.rawValue)
     }

     func refreshToken() -> String? {
         UserDefaults.standard.string(forKey: Key.refreshToken.rawValue)
     }

     func add(refreshToken: String) {
         UserDefaults.standard.set(refreshToken, forKey: Key.refreshToken.rawValue)
     }
 }
