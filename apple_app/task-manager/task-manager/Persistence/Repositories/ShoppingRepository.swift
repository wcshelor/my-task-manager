import Foundation

@MainActor
protocol ShoppingRepository {
    func fetchShoppingItems(includeHistory: Bool) throws -> [ShoppingItem]
    func fetchActiveShoppingItems() throws -> [ShoppingItem]
    func fetchShoppingHistory() throws -> [ShoppingItem]
    func shoppingItem(withID id: UUID) throws -> ShoppingItem?
    func saveShoppingItem(_ item: ShoppingItem, replacingItemWithID originalID: UUID?) throws
    func updateShoppingItemStatus(withID id: UUID, status: ShoppingItemStatus, at date: Date) throws
    func deleteShoppingItem(withID id: UUID) throws
}

