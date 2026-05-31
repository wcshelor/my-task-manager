import Foundation
import Testing
@testable import task_manager

struct SwiftDataFinanceRepositoryTests {
    @Test @MainActor func repositoryRoundTripsTransactionAndCategory() throws {
        let repository = try makeRepository()
        try repository.seedDefaultCategoriesIfNeeded()
        let category = try #require(repository.fetchCategories(includeArchived: false, kind: .expense).first)
        let transaction = FinanceTransaction(
            id: UUID(uuidString: "123E4567-E89B-12D3-A456-426614174111")!,
            name: "Groceries",
            amount: Decimal(string: "42.50")!,
            kind: .expense,
            date: Date(timeIntervalSince1970: 1_000),
            category: category,
            createdAt: Date(timeIntervalSince1970: 1_000)
        )

        try repository.saveTransaction(transaction, replacingTransactionWithID: nil)

        #expect(try repository.transaction(withID: transaction.id) == transaction)
    }

    @Test @MainActor func repositorySeedsCategoriesOnlyOnce() throws {
        let repository = try makeRepository()

        try repository.seedDefaultCategoriesIfNeeded()
        try repository.seedDefaultCategoriesIfNeeded()

        #expect(try repository.fetchCategories(includeArchived: false, kind: nil).count == FinanceCategory.defaultSeedCategories.count)
    }

    @Test @MainActor func repositoryFiltersTransactionsByMonth() throws {
        let repository = try makeRepository()
        try repository.seedDefaultCategoriesIfNeeded()
        let category = try #require(repository.fetchCategories(includeArchived: false, kind: .expense).first)
        let mayTransaction = FinanceTransaction(name: "May", amount: 10, kind: .expense, date: Date(timeIntervalSince1970: 1_714_521_600), category: category)
        let juneTransaction = FinanceTransaction(name: "June", amount: 20, kind: .expense, date: Date(timeIntervalSince1970: 1_717_113_600), category: category)

        try repository.saveTransaction(mayTransaction, replacingTransactionWithID: nil)
        try repository.saveTransaction(juneTransaction, replacingTransactionWithID: nil)

        let juneInterval = DateInterval(start: Date(timeIntervalSince1970: 1_717_027_200), end: Date(timeIntervalSince1970: 1_719_619_200))
        #expect(try repository.fetchTransactions(in: juneInterval).map(\.name) == ["June"])
    }

    @Test @MainActor func repositoryDeletesTransactions() throws {
        let repository = try makeRepository()
        let transaction = FinanceTransaction(name: "Delete", amount: 5, kind: .expense)

        try repository.saveTransaction(transaction, replacingTransactionWithID: nil)
        try repository.deleteTransaction(withID: transaction.id)

        #expect(try repository.fetchTransactions().isEmpty)
    }

    @MainActor
    private func makeRepository() throws -> SwiftDataFinanceRepository {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        return SwiftDataFinanceRepository(modelContainer: container)
    }
}
