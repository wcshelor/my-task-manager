import Foundation
import Testing
@testable import task_manager

struct FinanceSummaryServiceTests {
    @Test func monthIntervalReturnsMonthBounds() {
        let calendar = Calendar(identifier: .gregorian)
        let date = Date(timeIntervalSince1970: 1_717_113_600)

        let interval = FinanceSummaryService.monthInterval(containing: date, calendar: calendar)

        #expect(calendar.component(.day, from: interval.start) == 1)
        #expect(calendar.component(.month, from: interval.start) == 6)
        #expect(calendar.component(.month, from: interval.end.addingTimeInterval(-1)) == 6)
    }

    @Test func totalsAndBalanceRespectKinds() {
        let transactions = [
            FinanceTransaction(name: "Salary", amount: 3_000, kind: .income),
            FinanceTransaction(name: "Rent", amount: 900, kind: .expense),
            FinanceTransaction(name: "Food", amount: 100, kind: .expense),
        ]

        #expect(FinanceSummaryService.totalIncome(for: transactions) == 3_000)
        #expect(FinanceSummaryService.totalExpenses(for: transactions) == 1_000)
        #expect(FinanceSummaryService.monthlyBalance(for: transactions) == 2_000)
    }

    @Test func categorySpendingUsesExpensesOnly() {
        let food = FinanceCategory(name: "Food", kind: .expense)
        let salary = FinanceCategory(name: "Salary", kind: .income)
        let transactions = [
            FinanceTransaction(name: "Salary", amount: 4_000, kind: .income, category: salary),
            FinanceTransaction(name: "Lunch", amount: 20, kind: .expense, category: food),
            FinanceTransaction(name: "Dinner", amount: 30, kind: .expense, category: food),
        ]

        let slices = FinanceSummaryService.categorySpending(for: transactions)

        #expect(slices.count == 1)
        #expect(slices.first?.amount == 50)
        #expect(slices.first?.percentage == 1)
    }

    @Test func listGroupingIsDeterministic() {
        let food = FinanceCategory(name: "Food", kind: .expense)
        let groceries = FinanceCategory(name: "Groceries", kind: .expense)
        let firstDay = Date(timeIntervalSince1970: 1_717_113_600)
        let secondDay = Date(timeIntervalSince1970: 1_717_200_000)
        let transactions = [
            FinanceTransaction(name: "B", amount: 20, kind: .expense, date: secondDay, category: groceries),
            FinanceTransaction(name: "A", amount: 10, kind: .expense, date: firstDay, category: food),
        ]

        let dateSections = FinanceSummaryService.dateSections(for: transactions)
        let categorySections = FinanceSummaryService.categorySections(for: transactions)

        #expect(dateSections.map { $0.transactions.first?.name ?? "" } == ["B", "A"])
        #expect(categorySections.map(\.title) == ["Food", "Groceries"])
    }
}
