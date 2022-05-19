import Foundation

protocol RecommendedValidatorListParachainStrategyOutput: AnyObject {}

class RecommendedValidatorListParachainStrategy {
    var output: RecommendedValidatorListParachainStrategyOutput?
}

extension RecommendedValidatorListParachainStrategy: RecommendedValidatorListStrategy {
    func setup() {}
}
