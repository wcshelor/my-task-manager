import Foundation
import SwiftData

@Model
final class SyncConflictRecord {
    // Planned conflict log. The sync engine should preserve both sides here
    // before choosing a deterministic fallback merge result.
    var id: UUID = UUID()
    var entityType: String = ""
    var entityID: UUID = UUID()
    var detectedAt: Date = Date.distantPast
    var summary: String = ""
    var localPayloadJSON: String = ""
    var remotePayloadJSON: String = ""
    var resolvedAt: Date?

    init() {}
}
