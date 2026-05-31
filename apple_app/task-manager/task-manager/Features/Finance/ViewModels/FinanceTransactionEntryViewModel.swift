import Combine
import Foundation

@MainActor
final class FinanceTransactionEntryViewModel: ObservableObject {
    @Published var amountText = ""
    @Published var transactionName = ""
    @Published var note = ""
    @Published var newCategoryName = ""

    let kind: TransactionKind

    init(kind: TransactionKind) {
        self.kind = kind
    }

    var parsedAmount: Decimal? {
        FinanceFormatting.decimal(from: amountText)
    }

    var canSubmit: Bool {
        parsedAmount != nil && FinanceTransaction.cleanedName(from: transactionName) != nil
    }

    var canCreateCategory: Bool {
        canSubmit && FinanceCategory.cleanedName(from: newCategoryName) != nil
    }
}
