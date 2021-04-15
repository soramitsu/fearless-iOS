import Foundation
import FearlessUtils

final class ControllerMapper: Mapping {
    typealias InputType = JSON
    typealias OutputType = AccountId?

    func map(input: InputType) -> OutputType {
        guard ensureModule(input), ensureCall(input) else {
            return nil
        }

        guard let params = extractArguments(input) else {
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

    private func extractArguments(_ input: InputType) -> JSON? {
        if input.params?.arrayValue != nil {
            return input.params
        }

        if input.call_args?.arrayValue != nil {
            return input.call_args
        }

        let optParamsData = input.params?.stringValue?.data(using: .utf8) ??
            input.call_args?.stringValue?.data(using: .utf8)

        if let paramsData = optParamsData {
            return try? JSONDecoder().decode(JSON.self, from: paramsData)
        }

        return nil
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
