import Foundation
import FearlessUtils

final class NominateMapper: Mapping {
    typealias InputType = JSON
    typealias OutputType = [AccountId]?

    func map(input: InputType) -> OutputType {
        guard ensureModule(input), ensureCall(input) else {
            return nil
        }

        guard let paramsData = extractArguments(input),
              let params = try? JSONDecoder().decode(JSON.self, from: paramsData) else {
            return nil
        }

        guard let targetsArg = params.arrayValue?
            .first(where: { $0.name?.stringValue == "targets" })?.value?.arrayValue else {
            return nil
        }

        return targetsArg.compactMap { target in
            guard let accountId = target.stringValue ?? target.Id?.stringValue else {
                return nil
            }

            return try? Data(hexString: accountId)
        }
    }

    private func extractArguments(_ input: InputType) -> Data? {
        input.params?.stringValue?.data(using: .utf8) ??
            input.call_args?.stringValue?.data(using: .utf8)
    }

    private func ensureCall(_ input: JSON) -> Bool {
        let callName = input.call_module_function?.stringValue ??
            input.call_function?.stringValue ??
            input.call_name?.stringValue

        return callName == "nominate"
    }

    private func ensureModule(_ input: JSON) -> Bool {
        input.call_module_function?.stringValue == "Staking"
    }
}
