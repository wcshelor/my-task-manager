import Combine
import Foundation

@MainActor
final class FinanceDashboardViewModel: ObservableObject {
    @Published private(set) var transactions: [FinanceTransaction] = []
    @Published private(set) var categories: [FinanceCategory] = []
    @Published private(set) var selectedMonth: Date
    @Published private(set) var errorMessage: String?

    private let repository: any FinanceRepository
    private let calendar: Calendar
    private let nowProvider: @Sendable () -> Date
    private var hasLoaded = false

    init(
        repository: any FinanceRepository,
        selectedMonth: Date = Date(),
        calendar: Calendar = .current,
        nowProvider: @escaping @Sendable () -> Date = Date.init
    ) {
        self.repository = repository
        self.selectedMonth = selectedMonth
        self.calendar = calendar
        self.nowProvider = nowProvider
    }

    var monthInterval: DateInterval {
        FinanceSummaryService.monthInterval(containing: selectedMonth, calendar: calendar)
    }

    var monthTitle: String {
        selectedMonth.formatted(.dateTime.month(.wide).year())
    }

    var monthlyBalance: Decimal {
        FinanceSummaryService.monthlyBalance(for: transactions)
    }

    var totalIncome: Decimal {
        FinanceSummaryService.totalIncome(for: transactions)
    }

    var totalExpenses: Decimal {
        FinanceSummaryService.totalExpenses(for: transactions)
    }

    var spendingBreakdown: [FinanceCategorySpending] {
        FinanceSummaryService.categorySpending(for: transactions)
    }

    var expenseCategories: [FinanceCategory] {
        categories.filter { $0.kind == .expense || $0.kind == nil }
    }

    var incomeCategories: [FinanceCategory] {
        categories.filter { $0.kind == .income || $0.kind == nil }
    }

    func loadIfNeeded() {
        guard hasLoaded == false else {
            return
        }

        load()
    }

    func load() {
        do {
            try repository.seedDefaultCategoriesIfNeeded()
            categories = try repository.fetchCategories(includeArchived: false, kind: nil)
            transactions = try repository.fetchTransactions(in: monthInterval)
            errorMessage = nil
            hasLoaded = true
        } catch {
            errorMessage = "Unable to load finance: \(error.localizedDescription)"
        }
    }

    func selectPreviousMonth() {
        selectedMonth = calendar.date(byAdding: .month, value: -1, to: selectedMonth) ?? selectedMonth
        load()
    }

    func selectNextMonth() {
        selectedMonth = calendar.date(byAdding: .month, value: 1, to: selectedMonth) ?? selectedMonth
        load()
    }

    func saveTransaction(
        name: String,
        amount: Decimal,
        kind: TransactionKind,
        category: FinanceCategory,
        note: String? = nil
    ) -> Bool {
        guard FinanceTransaction.cleanedName(from: name) != nil else {
            return false
        }

        do {
            let now = nowProvider()
            let transaction = FinanceTransaction(
                name: name,
                amount: amount,
                kind: kind,
                date: now,
                category: category,
                note: note,
                createdAt: now,
                updatedAt: now
            )
            try repository.saveTransaction(transaction, replacingTransactionWithID: nil)
            load()
            return true
        } catch {
            errorMessage = "Unable to save finance transaction: \(error.localizedDescription)"
            return false
        }
    }

    func createCategoryAndSaveTransaction(
        categoryName: String,
        transactionName: String,
        amount: Decimal,
        kind: TransactionKind,
        note: String? = nil
    ) -> Bool {
        guard FinanceCategory.cleanedName(from: categoryName) != nil else {
            return false
        }

        do {
            let matchingCategories = try repository.fetchCategories(includeArchived: false, kind: nil)
            let nextSortOrder = (matchingCategories.map(\.sortOrder).max() ?? -1) + 1
            let category = FinanceCategory(name: categoryName, kind: kind, sortOrder: nextSortOrder)
            try repository.saveCategory(category, replacingCategoryWithID: nil)
            categories = try repository.fetchCategories(includeArchived: false, kind: nil)
            return saveTransaction(name: transactionName, amount: amount, kind: kind, category: category, note: note)
        } catch {
            errorMessage = "Unable to save finance category: \(error.localizedDescription)"
            return false
        }
    }

    func deleteTransaction(withID id: UUID) {
        do {
            try repository.deleteTransaction(withID: id)
            load()
        } catch {
            errorMessage = "Unable to delete finance transaction: \(error.localizedDescription)"
        }
    }
}
