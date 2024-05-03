

enum WalletTransactionHistoryDataState {
    case waitingCached
    case loading(page: Pagination, previousPage: Pagination?)
    case loaded(page: Pagination?, nextContext: PaginationContext?)
    case filtering(page: Pagination, previousPage: Pagination?)
    case filtered(page: Pagination?, nextContext: PaginationContext?)
}
