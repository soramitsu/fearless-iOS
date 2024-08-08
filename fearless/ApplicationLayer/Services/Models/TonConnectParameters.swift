import Foundation

public struct TonConnectParameters {
  public enum Version: String {
    case v2 = "2"
  }
  
  public let version: Version
  public let clientId: String
  public let requestPayload: TonConnectRequestPayload
  
  public init(version: Version, clientId: String, requestPayload: TonConnectRequestPayload) {
    self.version = version
    self.clientId = clientId
    self.requestPayload = requestPayload
  }
}
