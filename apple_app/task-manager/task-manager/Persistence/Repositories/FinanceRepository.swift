import Foundation

@MainActor
protocol FinanceRepository {
    func fetchTransactions() throws -> [FinanceTransaction]
    func fetchTransactions(in interval: DateInterval) throws -> [FinanceTransaction]
    func transaction(withID id: UUID) throws -> FinanceTransaction?
    func saveTransaction(_ transaction: FinanceTransaction, replacingTransactionWithID originalID: UUID?) throws
    func deleteTransaction(withID id: UUID) throws

    func fetchCategories(includeArchived: Bool, kind: TransactionKind?) throws -> [FinanceCategory]
    func category(withID id: UUID) throws -> FinanceCategory?
    func saveCategory(_ category: FinanceCategory, replacingCategoryWithID originalID: UUID?) throws
    func seedDefaultCategoriesIfNeeded() throws
}
