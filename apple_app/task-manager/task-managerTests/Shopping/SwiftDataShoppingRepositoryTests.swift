import Foundation
import Testing
@testable import task_manager

struct SwiftDataShoppingRepositoryTests {
    @Test @MainActor func shoppingRepositoryRoundTripsItem() throws {
        let repository = try makeRepository()
        let item = ShoppingItem(
            id: UUID(uuidString: "123E4567-E89B-12D3-A456-426614174111")!,
            title: "Milk",
            notes: "Two bottles",
            category: "Groceries",
            storeType: "Grocery",
            storeName: "Rewe",
            urgency: .needSoon,
            necessity: .necessary,
            createdAt: Date(timeIntervalSince1970: 1_000)
        )

        try repository.saveShoppingItem(item, replacingItemWithID: nil)

        #expect(try repository.shoppingItem(withID: item.id) == item)
    }

    @Test @MainActor func shoppingRepositoryUpdatesExistingItem() throws {
        let repository = try makeRepository()
        let original = ShoppingItem(title: "Milk")
        let updated = ShoppingItem(
            id: UUID(uuidString: "123E4567-E89B-12D3-A456-426614174222")!,
            title: "Oat milk",
            createdAt: original.createdAt,
            updatedAt: Date(timeIntervalSince1970: 2_000)
        )

        try repository.saveShoppingItem(original, replacingItemWithID: nil)
        try repository.saveShoppingItem(updated, replacingItemWithID: original.id)

        #expect(try repository.fetchShoppingItems(includeHistory: true) == [updated])
    }

    @Test @MainActor func shoppingRepositoryFiltersActiveAndHistory() throws {
        let repository = try makeRepository()
        let needed = ShoppingItem(title: "Coffee")
        let skipped = ShoppingItem(title: "Cake").updatingStatus(
            .skipped,
            at: Date(timeIntervalSince1970: 2_000)
        )

        try repository.saveShoppingItem(needed, replacingItemWithID: nil)
        try repository.saveShoppingItem(skipped, replacingItemWithID: nil)

        #expect(try repository.fetchActiveShoppingItems().map(\.title) == ["Coffee"])
        #expect(try repository.fetchShoppingHistory().map(\.title) == ["Cake"])
    }

    @Test @MainActor func shoppingRepositorySortsDeterministically() throws {
        let repository = try makeRepository()
        let base = Date(timeIntervalSince1970: 1_000)
        let laterOptional = ShoppingItem(
            title: "Chocolate",
            storeType: "Grocery",
            urgency: .needSoon,
            necessity: .optional,
            createdAt: base.addingTimeInterval(10)
        )
        let soonerNecessary = ShoppingItem(
            title: "Bread",
            storeType: "Grocery",
            urgency: .needSoon,
            necessity: .necessary,
            createdAt: base.addingTimeInterval(20)
        )
        let drugstore = ShoppingItem(
            title: "Soap",
            storeType: "Drugstore",
            urgency: .someday,
            necessity: .useful,
            createdAt: base
        )

        try repository.saveShoppingItem(laterOptional, replacingItemWithID: nil)
        try repository.saveShoppingItem(soonerNecessary, replacingItemWithID: nil)
        try repository.saveShoppingItem(drugstore, replacingItemWithID: nil)

        #expect(try repository.fetchActiveShoppingItems().map(\.title) == [
            "Soap",
            "Bread",
            "Chocolate",
        ])
    }

    @Test @MainActor func shoppingRepositoryDeletesItem() throws {
        let repository = try makeRepository()
        let item = ShoppingItem(title: "Delete me")

        try repository.saveShoppingItem(item, replacingItemWithID: nil)
        try repository.deleteShoppingItem(withID: item.id)

        #expect(try repository.fetchShoppingItems(includeHistory: true).isEmpty)
    }

    @MainActor
    private func makeRepository() throws -> SwiftDataShoppingRepository {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        return SwiftDataShoppingRepository(modelContainer: container)
    }
}

