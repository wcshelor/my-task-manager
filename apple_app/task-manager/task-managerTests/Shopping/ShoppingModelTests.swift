import Foundation
import Testing
@testable import task_manager

struct ShoppingModelTests {
    @Test func shoppingItemCleansTextAndUsesDefaults() {
        let createdAt = Date(timeIntervalSince1970: 1_000)
        let item = ShoppingItem(
            title: "  Milk  ",
            notes: "  Two bottles  ",
            category: "  Groceries  ",
            storeType: "  Grocery  ",
            storeName: "  Rewe  ",
            createdAt: createdAt
        )

        #expect(item.title == "Milk")
        #expect(item.notes == "Two bottles")
        #expect(item.category == "Groceries")
        #expect(item.storeType == "Grocery")
        #expect(item.storeName == "Rewe")
        #expect(item.urgency == .nextTrip)
        #expect(item.necessity == .necessary)
        #expect(item.status == .needed)
        #expect(item.completedAt == nil)
        #expect(item.updatedAt == createdAt)
    }

    @Test func newTitleInitializerRejectsEmptyTitles() {
        #expect(ShoppingItem(newTitle: "  ") == nil)
        #expect(ShoppingItem(newTitle: " Eggs ")?.title == "Eggs")
    }

    @Test func statusTransitionsSetAndClearCompletionDate() {
        let createdAt = Date(timeIntervalSince1970: 1_000)
        let completedAt = Date(timeIntervalSince1970: 2_000)
        let reopenedAt = Date(timeIntervalSince1970: 3_000)
        let item = ShoppingItem(title: "Coffee", createdAt: createdAt)

        let bought = item.updatingStatus(.bought, at: completedAt)

        #expect(bought.status == .bought)
        #expect(bought.completedAt == completedAt)
        #expect(bought.updatedAt == completedAt)

        let reopened = bought.updatingStatus(.needed, at: reopenedAt)

        #expect(reopened.status == .needed)
        #expect(reopened.completedAt == nil)
        #expect(reopened.updatedAt == reopenedAt)
    }

    @Test func missingStoreTypeUsesUnspecifiedTripGroup() {
        let item = ShoppingItem(title: "Batteries")

        #expect(item.tripGroupName == "Unspecified")
    }
}

