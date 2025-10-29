// These typealiases disambiguate model names used in generated Cuckoo mocks
// where both the app module and SSFModels export similarly named types.

@testable import fearless
import SSFModels

typealias ChainAccountResponse = fearless.ChainAccountResponse
typealias MetaAccountModel = fearless.MetaAccountModel

