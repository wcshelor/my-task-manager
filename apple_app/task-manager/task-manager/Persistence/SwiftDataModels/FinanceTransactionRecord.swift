import Foundation
import SwiftData

@Model
final class FinanceTransactionRecord {
    var id: UUID = UUID()
    var name: String = ""
    var amount: Decimal = 0
    var kindRawValue: String = TransactionKind.expense.rawValue
    var date: Date = Date.distantPast
    var note: String?
    var createdAt: Date = Date.distantPast
    var updatedAt: Date = Date.distantPast
    @Relationship(deleteRule: .nullify) var categoryRecord: FinanceCategoryRecord?

    init(transaction: FinanceTransaction, categoryRecord: FinanceCategoryRecord?) {
        update(from: transaction, categoryRecord: categoryRecord)
    }

    var transaction: FinanceTransaction {
        FinanceTransaction(
            id: id,
            name: name,
            amount: amount,
            kind: TransactionKind(rawValue: kindRawValue) ?? .expense,
            date: date,
            category: categoryRecord?.category,
            note: note,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    func update(from transaction: FinanceTransaction, categoryRecord: FinanceCategoryRecord?) {
        id = transaction.id
        name = transaction.name
        amount = transaction.amount
        kindRawValue = transaction.kind.rawValue
        date = transaction.date
        note = transaction.note
        createdAt = transaction.createdAt
        updatedAt = transaction.updatedAt
        self.categoryRecord = categoryRecord
    }
}
