import Foundation
import SwiftData

@Model
final class SyncStateRecord {
    // Planned local metadata for folder sync. This is not user data; it tracks
    // what this device has pushed and which remote batches it has applied.
    var id: String = "sync-state"
    var isEnabled: Bool = false
    var deviceID: UUID = UUID()
    var lastSyncAt: Date?
    var lastAppliedRemoteBatchID: String?
    var nextLocalSequenceNumber: Int = 1

    init() {}
}
