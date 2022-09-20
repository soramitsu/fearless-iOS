import Foundation
import FearlessUtils

extension RuntimeCall {
    init(callCodingPath: CallCodingPath, args: T) {
        self.init(
            moduleName: callCodingPath.moduleName,
            callName: callCodingPath.callName,
            args: args
        )
    }
}
