import Foundation

nonisolated struct FinanceCategorySpending: Identifiable, Equatable, Sendable {
    let category: FinanceCategory?
    let amount: Decimal
    let percentage: Decimal

    var id: UUID {
        category?.id ?? UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
    }

    var displayName: String {
        category?.name ?? "Uncategorized"
    }
}

nonisolated struct FinanceDateSection: Identifiable, Equatable, Sendable {
    let date: Date
    let transactions: [FinanceTransaction]

    var id: Date { date }
}

nonisolated struct FinanceCategorySection: Identifiable, Equatable, Sendable {
    let category: FinanceCategory?
    let transactions: [FinanceTransaction]

    var id: UUID {
        category?.id ?? UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
    }

    var title: String {
        category?.name ?? "Uncategorized"
    }
}

nonisolated enum FinanceSummaryService {
    static func monthInterval(containing date: Date, calendar: Calendar = .current) -> DateInterval {
        let start = calendar.date(from: calendar.dateComponents([.year, .month], from: date))
            ?? calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .month, value: 1, to: start)
            ?? start.addingTimeInterval(31 * 86_400)
        return DateInterval(start: start, end: end)
    }

    static func totalIncome(for transactions: [FinanceTransaction]) -> Decimal {
        transactions
            .filter { $0.kind == .income }
            .reduce(0) { $0 + $1.amount }
    }

    static func totalExpenses(for transactions: [FinanceTransaction]) -> Decimal {
        transactions
            .filter { $0.kind == .expense }
            .reduce(0) { $0 + $1.amount }
    }

    static func monthlyBalance(for transactions: [FinanceTransaction]) -> Decimal {
        totalIncome(for: transactions) - totalExpenses(for: transactions)
    }

    static func expenseTransactionsByCategory(for transactions: [FinanceTransaction]) -> [FinanceCategorySection] {
        let grouped = Dictionary(grouping: transactions.filter { $0.kind == .expense }, by: { $0.category })
        return grouped
            .map { category, transactions in
                FinanceCategorySection(
                    category: category,
                    transactions: transactions.sorted(by: transactionSortAscending)
                )
            }
            .sorted { lhs, rhs in
                let lhsTotal = lhs.transactions.reduce(0) { $0 + $1.amount }
                let rhsTotal = rhs.transactions.reduce(0) { $0 + $1.amount }
                if lhsTotal != rhsTotal {
                    return lhsTotal > rhsTotal
                }
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
    }

    static func categorySpending(for transactions: [FinanceTransaction]) -> [FinanceCategorySpending] {
        let expenseTransactions = transactions.filter { $0.kind == .expense }
        let totalExpenses = totalExpenses(for: expenseTransactions)
        guard totalExpenses > 0 else {
            return []
        }

        return expenseTransactionsByCategory(for: expenseTransactions).map { section in
            let amount = section.transactions.reduce(0) { $0 + $1.amount }
            return FinanceCategorySpending(
                category: section.category,
                amount: amount,
                percentage: decimalDivision(amount, by: totalExpenses)
            )
        }
    }

    static func dateSections(for transactions: [FinanceTransaction], calendar: Calendar = .current) -> [FinanceDateSection] {
        let grouped = Dictionary(grouping: transactions) { transaction in
            calendar.startOfDay(for: transaction.date)
        }

        return grouped
            .map { date, transactions in
                FinanceDateSection(date: date, transactions: transactions.sorted(by: transactionSortAscending))
            }
            .sorted { $0.date > $1.date }
    }

    static func categorySections(for transactions: [FinanceTransaction]) -> [FinanceCategorySection] {
        let grouped = Dictionary(grouping: transactions, by: { $0.category })

        return grouped
            .map { category, transactions in
                FinanceCategorySection(category: category, transactions: transactions.sorted(by: transactionSortAscending))
            }
            .sorted { lhs, rhs in
                lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
    }

    private static func transactionSortAscending(_ lhs: FinanceTransaction, _ rhs: FinanceTransaction) -> Bool {
        if lhs.date != rhs.date {
            return lhs.date > rhs.date
        }

        if lhs.kind != rhs.kind {
            return lhs.kind == .income
        }

        return lhs.id.uuidString < rhs.id.uuidString
    }

    private static func decimalDivision(_ lhs: Decimal, by rhs: Decimal) -> Decimal {
        guard rhs != 0 else {
            return 0
        }

        return NSDecimalNumber(decimal: lhs)
            .dividing(by: NSDecimalNumber(decimal: rhs))
            .decimalValue
    }
}
