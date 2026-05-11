import Foundation
import Testing
@testable import task_manager

@MainActor
struct ShoppingListViewModelTests {
    @Test func viewModelQuickAddsAndGroupsActiveItems() {
        let now = Date(timeIntervalSince1970: 1_000)
        let repository = FakeShoppingRepository()
        let viewModel = ShoppingListViewModel(
            shoppingRepository: repository,
            nowProvider: { now }
        )

        viewModel.loadIfNeeded()
        viewModel.quickAdd(title: "  Milk  ")

        #expect(repository.items.first?.title == "Milk")
        #expect(repository.items.first?.createdAt == now)
        #expect(viewModel.activeTripGroups().map(\.title) == ["Unspecified"])
    }

    @Test func viewModelMovesBoughtItemsIntoHistory() {
        let now = Date(timeIntervalSince1970: 2_000)
        let item = ShoppingItem(title: "Coffee")
        let repository = FakeShoppingRepository(items: [item])
        let viewModel = ShoppingListViewModel(
            shoppingRepository: repository,
            nowProvider: { now }
        )

        viewModel.loadIfNeeded()
        viewModel.markBought(withID: item.id)

        #expect(viewModel.activeItems.isEmpty)
        #expect(viewModel.historyItems.map(\.title) == ["Coffee"])
        #expect(viewModel.historyItems.first?.completedAt == now)
    }

    @Test func viewModelFiltersTripGroupsBySearchText() {
        let repository = FakeShoppingRepository(items: [
            ShoppingItem(title: "Milk", storeType: "Grocery"),
            ShoppingItem(title: "Ibuprofen", storeType: "Drugstore"),
        ])
        let viewModel = ShoppingListViewModel(shoppingRepository: repository)

        viewModel.loadIfNeeded()

        #expect(viewModel.activeTripGroups(searchText: "ibu").map(\.title) == ["Drugstore"])
    }

    @Test func viewModelExposesRepositoryErrors() {
        let repository = FakeShoppingRepository()
        repository.shouldThrow = true
        let viewModel = ShoppingListViewModel(shoppingRepository: repository)

        viewModel.loadIfNeeded()

        #expect(viewModel.errorMessage?.contains("Unable to load shopping") == true)
    }
}

@MainActor
private final class FakeShoppingRepository: ShoppingRepository {
    enum FakeError: Error {
        case failed
    }

    var items: [ShoppingItem]
    var shouldThrow = false

    init(items: [ShoppingItem] = []) {
        self.items = items
    }

    func fetchShoppingItems(includeHistory: Bool) throws -> [ShoppingItem] {
        if shouldThrow {
            throw FakeError.failed
        }

        if includeHistory {
            return items.sortedForShoppingTrips()
        }

        return items.filter(\.isActive).sortedForShoppingTrips()
    }

    func fetchActiveShoppingItems() throws -> [ShoppingItem] {
        try fetchShoppingItems(includeHistory: false)
    }

    func fetchShoppingHistory() throws -> [ShoppingItem] {
        if shouldThrow {
            throw FakeError.failed
        }

        return items
            .filter { $0.isActive == false }
            .sorted { leftItem, rightItem in
                (leftItem.completedAt ?? leftItem.updatedAt) > (rightItem.completedAt ?? rightItem.updatedAt)
            }
    }

    func shoppingItem(withID id: UUID) throws -> ShoppingItem? {
        if shouldThrow {
            throw FakeError.failed
        }

        return items.first { $0.id == id }
    }

    func saveShoppingItem(_ item: ShoppingItem, replacingItemWithID originalID: UUID?) throws {
        if shouldThrow {
            throw FakeError.failed
        }

        let targetID = originalID ?? item.id
        if let index = items.firstIndex(where: { $0.id == targetID || $0.id == item.id }) {
            items[index] = item
        } else {
            items.append(item)
        }
    }

    func updateShoppingItemStatus(
        withID id: UUID,
        status: ShoppingItemStatus,
        at date: Date
    ) throws {
        if shouldThrow {
            throw FakeError.failed
        }

        guard let item = items.first(where: { $0.id == id }) else {
            return
        }

        try saveShoppingItem(
            item.updatingStatus(status, at: date),
            replacingItemWithID: id
        )
    }

    func deleteShoppingItem(withID id: UUID) throws {
        if shouldThrow {
            throw FakeError.failed
        }

        items.removeAll { $0.id == id }
    }
}
