import Combine
import Foundation

@MainActor
final class ShoppingListViewModel: ObservableObject {
    @Published private(set) var activeItems: [ShoppingItem] = []
    @Published private(set) var historyItems: [ShoppingItem] = []
    @Published private(set) var errorMessage: String?

    private let shoppingRepository: any ShoppingRepository
    private let nowProvider: @Sendable () -> Date
    private var hasLoaded = false

    init(
        shoppingRepository: any ShoppingRepository,
        nowProvider: @escaping @Sendable () -> Date = Date.init
    ) {
        self.shoppingRepository = shoppingRepository
        self.nowProvider = nowProvider
    }

    func loadIfNeeded() {
        guard hasLoaded == false else {
            return
        }

        load()
    }

    func load() {
        do {
            activeItems = try shoppingRepository.fetchActiveShoppingItems()
            historyItems = try shoppingRepository.fetchShoppingHistory()
            errorMessage = nil
            hasLoaded = true
        } catch {
            errorMessage = "Unable to load shopping: \(error.localizedDescription)"
        }
    }

    func saveItem(_ item: ShoppingItem, replacingItemWithID originalID: UUID? = nil) {
        do {
            try shoppingRepository.saveShoppingItem(item, replacingItemWithID: originalID)
            load()
        } catch {
            errorMessage = "Unable to save shopping item: \(error.localizedDescription)"
        }
    }

    func quickAdd(title: String) {
        guard let item = ShoppingItem(newTitle: title, createdAt: nowProvider()) else {
            return
        }

        saveItem(item)
    }

    func markBought(withID id: UUID) {
        updateStatus(withID: id, status: .bought)
    }

    func skipItem(withID id: UUID) {
        updateStatus(withID: id, status: .skipped)
    }

    func archiveItem(withID id: UUID) {
        updateStatus(withID: id, status: .archived)
    }

    func reopenItem(withID id: UUID) {
        updateStatus(withID: id, status: .needed)
    }

    func deleteItem(withID id: UUID) {
        do {
            try shoppingRepository.deleteShoppingItem(withID: id)
            load()
        } catch {
            errorMessage = "Unable to delete shopping item: \(error.localizedDescription)"
        }
    }

    func activeTripGroups(searchText: String = "") -> [ShoppingTripGroup] {
        Self.tripGroups(from: filtered(activeItems, searchText: searchText))
    }

    func history(searchText: String = "") -> [ShoppingItem] {
        filtered(historyItems, searchText: searchText)
    }

    static func tripGroups(from items: [ShoppingItem]) -> [ShoppingTripGroup] {
        let sortedItems = items.sortedForShoppingTrips()
        let grouped = Dictionary(grouping: sortedItems, by: \.storeType)

        return grouped
            .map { storeType, items in
                ShoppingTripGroup(storeType: storeType, items: items)
            }
            .sorted { leftGroup, rightGroup in
                leftGroup.title.localizedCaseInsensitiveCompare(rightGroup.title) == .orderedAscending
            }
    }

    private func updateStatus(withID id: UUID, status: ShoppingItemStatus) {
        do {
            try shoppingRepository.updateShoppingItemStatus(
                withID: id,
                status: status,
                at: nowProvider()
            )
            load()
        } catch {
            errorMessage = "Unable to update shopping item: \(error.localizedDescription)"
        }
    }

    private func filtered(_ items: [ShoppingItem], searchText: String) -> [ShoppingItem] {
        let cleanedSearchText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanedSearchText.isEmpty == false else {
            return items
        }

        return items.filter { item in
            [
                item.title,
                item.notes,
                item.category,
                item.storeType,
                item.storeName,
            ]
            .compactMap { $0?.localizedLowercase }
            .contains { $0.contains(cleanedSearchText.localizedLowercase) }
        }
    }
}
