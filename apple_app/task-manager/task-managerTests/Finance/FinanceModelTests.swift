import Foundation
import Testing
@testable import task_manager

struct FinanceModelTests {
    @Test func transactionCleansTextAndUsesPositiveAmount() {
        let createdAt = Date(timeIntervalSince1970: 1_000)
        let transaction = FinanceTransaction(
            name: "  Rent  ",
            amount: Decimal(string: "-949.75")!,
            kind: .expense,
            note: "  June  ",
            createdAt: createdAt
        )

        #expect(transaction.name == "Rent")
        #expect(transaction.amount == Decimal(string: "949.75")!)
        #expect(transaction.note == "June")
        #expect(transaction.updatedAt == createdAt)
    }

    @Test func categoryCleansTextAndDefaultsSortOrder() {
        let category = FinanceCategory(name: "  Food  ", colorHex: "  #FF0000  ", sortOrder: -1)

        #expect(category.name == "Food")
        #expect(category.colorHex == "#FF0000")
        #expect(category.sortOrder == 0)
    }

    @Test func signedAmountUsesKindSemantics() {
        let income = FinanceTransaction(name: "Salary", amount: 1_000, kind: .income)
        let expense = FinanceTransaction(name: "Rent", amount: 500, kind: .expense)

        #expect(income.signedAmount == 1_000)
        #expect(expense.signedAmount == -500)
    }
}
