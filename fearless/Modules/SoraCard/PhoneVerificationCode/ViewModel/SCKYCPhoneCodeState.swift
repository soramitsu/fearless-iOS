import Foundation

enum SCKYCPhoneCodeState {
    case editing
    case sent
    case wrong(String)
    case succeed
}
