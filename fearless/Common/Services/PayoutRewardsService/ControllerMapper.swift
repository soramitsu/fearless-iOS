import Foundation
import FearlessUtils

final class ControllerMapper: Mapping {
    typealias InputType = JSON
    typealias OutputType = AccountId?

    func map(input: InputType) -> OutputType {
        guard ensureModule(input), ensureCall(input) else {
            return nil
        }

        guard let paramsData = extractArguments(input),
              let params = try? JSONDecoder().decode(JSON.self, from: paramsData) else {
            return nil
        }

        let controllerArg = params.arrayValue?
            .first(where: { $0.name?.stringValue == "controller" })

        guard let controllerHex = controllerArg?.value?.stringValue ??
            controllerArg?.value?.Id?.stringValue else {
            return nil
        }

        return try? Data(hexString: controllerHex)
    }

    private func extractArguments(_ input: InputType) -> Data? {
        input.params?.stringValue?.data(using: .utf8) ??
            input.call_args?.stringValue?.data(using: .utf8)
    }

    private func ensureCall(_ input: JSON) -> Bool {
        let optCallName = input.call_module_function?.stringValue ??
            input.call_function?.stringValue ??
            input.call_name?.stringValue

        guard let callName = optCallName else {
            return false
        }

        return ["bond", "set_controller"].contains(callName)
    }

    private func ensureModule(_ input: JSON) -> Bool {
        input.call_module?.stringValue == "Staking"
    }
}
