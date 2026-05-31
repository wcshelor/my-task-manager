import Foundation
import SwiftData

@MainActor
final class SwiftDataFinanceRepository: FinanceRepository {
    private let modelContext: ModelContext

    init(modelContainer: ModelContainer) {
        self.modelContext = modelContainer.mainContext
    }

    func fetchTransactions() throws -> [FinanceTransaction] {
        try fetchAllTransactionRecords()
            .map(\.transaction)
            .sorted(by: Self.transactionSort)
    }

    func fetchTransactions(in interval: DateInterval) throws -> [FinanceTransaction] {
        try fetchTransactions().filter { interval.contains($0.date) }
    }

    func transaction(withID id: UUID) throws -> FinanceTransaction? {
        try fetchTransactionRecord(withID: id)?.transaction
    }

    func saveTransaction(_ transaction: FinanceTransaction, replacingTransactionWithID originalID: UUID?) throws {
        let categoryRecord = try recordForCategory(transaction.category)
        let record = try fetchTransactionRecord(withID: originalID ?? transaction.id)
            ?? fetchTransactionRecord(withID: transaction.id)

        if let record {
            record.update(from: transaction, categoryRecord: categoryRecord)
        } else {
            modelContext.insert(FinanceTransactionRecord(transaction: transaction, categoryRecord: categoryRecord))
        }

        try modelContext.save()
    }

    func deleteTransaction(withID id: UUID) throws {
        guard let record = try fetchTransactionRecord(withID: id) else {
            return
        }

        modelContext.delete(record)
        try modelContext.save()
    }

    func fetchCategories(includeArchived: Bool = false, kind: TransactionKind? = nil) throws -> [FinanceCategory] {
        try fetchAllCategoryRecords()
            .map(\.category)
            .filter { category in
                (includeArchived || category.isArchived == false)
                    && (kind == nil || category.kind == nil || category.kind == kind)
            }
            .sorted(by: Self.categorySort)
    }

    func category(withID id: UUID) throws -> FinanceCategory? {
        try fetchCategoryRecord(withID: id)?.category
    }

    func saveCategory(_ category: FinanceCategory, replacingCategoryWithID originalID: UUID?) throws {
        let record = try fetchCategoryRecord(withID: originalID ?? category.id)
            ?? fetchCategoryRecord(withID: category.id)

        if let record {
            record.update(from: category)
        } else {
            modelContext.insert(FinanceCategoryRecord(category: category))
        }

        try modelContext.save()
    }

    func seedDefaultCategoriesIfNeeded() throws {
        guard try fetchAllCategoryRecords().isEmpty else {
            return
        }

        for (index, seed) in FinanceCategory.defaultSeedCategories.enumerated() {
            modelContext.insert(
                FinanceCategoryRecord(
                    category: FinanceCategory(
                        name: seed.name,
                        kind: seed.kind,
                        sortOrder: index
                    )
                )
            )
        }

        try modelContext.save()
    }

    private func recordForCategory(_ category: FinanceCategory?) throws -> FinanceCategoryRecord? {
        guard let category else {
            return nil
        }

        return try fetchCategoryRecord(withID: category.id)
    }

    private func fetchAllTransactionRecords() throws -> [FinanceTransactionRecord] {
        try modelContext.fetch(FetchDescriptor<FinanceTransactionRecord>())
    }

    private func fetchAllCategoryRecords() throws -> [FinanceCategoryRecord] {
        try modelContext.fetch(FetchDescriptor<FinanceCategoryRecord>())
    }

    private func fetchTransactionRecord(withID id: UUID) throws -> FinanceTransactionRecord? {
        try fetchAllTransactionRecords().first { $0.id == id }
    }

    private func fetchCategoryRecord(withID id: UUID) throws -> FinanceCategoryRecord? {
        try fetchAllCategoryRecords().first { $0.id == id }
    }

    private static func transactionSort(_ lhs: FinanceTransaction, _ rhs: FinanceTransaction) -> Bool {
        if lhs.date != rhs.date {
            return lhs.date > rhs.date
        }

        if lhs.createdAt != rhs.createdAt {
            return lhs.createdAt > rhs.createdAt
        }

        return lhs.id.uuidString < rhs.id.uuidString
    }

    private static func categorySort(_ lhs: FinanceCategory, _ rhs: FinanceCategory) -> Bool {
        if lhs.sortOrder != rhs.sortOrder {
            return lhs.sortOrder < rhs.sortOrder
        }

        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }
}
