import Foundation
import SwiftData

@Model
final class FinanceCategoryRecord {
    var id: UUID = UUID()
    var name: String = ""
    var kindRawValue: String?
    var colorHex: String?
    var iconName: String?
    var sortOrder: Int = 0
    var isArchived: Bool = false
    var createdAt: Date = Date.distantPast

    init(category: FinanceCategory) {
        update(from: category)
    }

    var category: FinanceCategory {
        FinanceCategory(
            id: id,
            name: name,
            kind: kindRawValue.flatMap(TransactionKind.init(rawValue:)),
            colorHex: colorHex,
            iconName: iconName,
            sortOrder: sortOrder,
            isArchived: isArchived,
            createdAt: createdAt
        )
    }

    func update(from category: FinanceCategory) {
        id = category.id
        name = category.name
        kindRawValue = category.kind?.rawValue
        colorHex = category.colorHex
        iconName = category.iconName
        sortOrder = category.sortOrder
        isArchived = category.isArchived
        createdAt = category.createdAt
    }
}
