import Foundation
import SwiftData

@Model
final class SyncTombstoneRecord {
    // Planned delete marker. Folder sync needs tombstones so a deleted record
    // does not come back when another device later pushes an older snapshot.
    var id: UUID = UUID()
    var entityType: String = ""
    var entityID: UUID = UUID()
    var deletedAt: Date = Date.distantPast
    var deletedByDeviceID: UUID = UUID()

    init() {}
}
