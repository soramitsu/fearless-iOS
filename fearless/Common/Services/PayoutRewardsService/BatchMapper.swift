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
}
