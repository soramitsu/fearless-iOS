import Foundation
import FearlessUtils

final class BatchMapper<R>: Mapping {
    typealias InputType = JSON
    typealias OutputType = [R]

    let innerMapper: AnyMapper<JSON, R>

    init(innerMapper: AnyMapper<JSON, R>) {
        self.innerMapper = innerMapper
    }

    func map(input: JSON) -> OutputType {
        let call = input.params?.value?.arrayValue ?? []

        return call.map { innerMapper.map(input: $0) }
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
}
