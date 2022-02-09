import Foundation
import FearlessUtils

protocol ConnectionStateReporting {
    var state: WebSocketEngine.State { get }
}
