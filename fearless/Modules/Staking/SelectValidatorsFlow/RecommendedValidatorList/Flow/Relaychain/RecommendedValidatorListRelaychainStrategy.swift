import Foundation

protocol RecommendedValidatorListRelaychainStrategyOutput: AnyObject {}

class RecommendedValidatorListRelaychainStrategy {
    var output: RecommendedValidatorListRelaychainStrategyOutput?
}

extension RecommendedValidatorListRelaychainStrategy: RecommendedValidatorListStrategy {
    func setup() {}
}
