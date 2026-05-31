import Foundation
import SwiftData

@Model
final class ViceRecord {
    var id: UUID = UUID()
    var name: String = ""
    var unitLabel: String = ""
    var createdAt: Date = Date.distantPast
    var updatedAt: Date = Date.distantPast
    var isArchived: Bool = false

    init(vice: Vice) {
        update(from: vice)
    }

    var vice: Vice {
        Vice(
            id: id,
            name: name,
            unitLabel: unitLabel,
            createdAt: createdAt,
            updatedAt: updatedAt,
            isArchived: isArchived
        )
    }

    func update(from vice: Vice) {
        id = vice.id
        name = vice.name
        unitLabel = vice.unitLabel
        createdAt = vice.createdAt
        updatedAt = vice.updatedAt
        isArchived = vice.isArchived
    }
}
